#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"

# -----------------------------
# 0) Ensure we're in a git repo
# -----------------------------
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "==> Initializing git repo in: $ROOT"
  git init
  git config user.email "sf@local" || true
  git config user.name "software-factory" || true
fi

# Ensure at least one commit exists (worktrees require a commit)
if ! git rev-parse HEAD >/dev/null 2>&1; then
  echo "==> Creating initial commit (required for worktrees)"
  touch .gitignore
  git add -A || true
  git commit --allow-empty -m "init: factory repo" >/dev/null 2>&1 || true
fi

BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

mkdir -p scripts prompts runs data .worktrees apps packages pipelines templates tools docs

# -----------------------------
# 1) .gitignore (avoid junk)
# -----------------------------
cat > .gitignore <<'EOF'
node_modules/
dist/
.next/
.turbo/
coverage/
playwright-report/
test-results/
data/
runs/
.worktrees/
*.log
EOF
git add .gitignore >/dev/null 2>&1 || true

# -----------------------------
# 2) SPEC + AGENTS (rules + tech stack)
# -----------------------------
cat > SPEC.md <<'EOF'
# SF Factory OS — SPEC (Final)

You are building a **local-first autonomous software factory** that can build many products/day.

## Hard Constraints
- Subscription-only: **NO API KEYS**. Codex CLI (ChatGPT auth), Claude Code (subscription auth).
- TypeScript-first.
- Real-time WebUI visibility for everything.
- Multi-product & multi-run concurrency.
- Stop/Resume for every run.
- Self-verifying: deterministic tests + scenario evaluation + statistical acceptance.

## Tech Stack (Factory Itself)
- apps/web: Next.js (App Router) + TypeScript + Tailwind
- apps/api: Fastify + TypeScript, DDD folders:
  - domain/ application/ infrastructure/ interfaces/http/ tests/
- Persistence: SQLite (local-first)
- Event stream: SSE (server-sent events)
- Verification:
  - Typecheck (tsc)
  - Unit tests (Vitest)
  - E2E (Playwright)
  - Scenario harness + satisfaction metric
  - Statistical gate (Clopper–Pearson lower confidence bound)
- Orchestration:
  - Run engine is **DOT pipeline execution** (Attractor-style).
  - For v1, implement a minimal DOT runner in TS OR call an external runner via tool wrapper.
  - Store full evidence per run under runs/<runId>/...

## Model Matrix (Defaults)
- implement_ts_fast: Codex Spark (xhigh)
- implement_ts_deep: Codex (xhigh)
- review: Claude Opus
- plan: Claude OpusPlan (Opus plans → Sonnet executes)
- fallback: Claude Sonnet, Codex 5.2-codex

## Correctness Strategy (Core Novelty)
- Don’t trust “LLM wrote tests therefore tests passing = correct.”
- Maintain **holdout scenarios** not visible to implementers.
- Run tournament parallel candidates.
- Accept only if:
  - deterministic gates pass AND
  - Clopper–Pearson lower bound >= threshold (default 0.98 at alpha=0.05)

EOF

cat > AGENTS.md <<'EOF'
# AGENTS.md — Always-on agent contract (Codex + Claude)

Non-negotiable:
- SUBSCRIPTIONS ONLY. Never add API keys, never require OPENAI_API_KEY or ANTHROPIC_API_KEY.
- Use TypeScript-first.
- apps/api MUST follow DDD folders:
  domain/ application/ infrastructure/ interfaces/http/ tests/
- Every stage emits structured events for UI.
- No big refactors; minimal patches.

Definition of done for any lane:
- typecheck
- unit tests
- basic docs
- commits with clear message

EOF

# -----------------------------
# 3) Preflight: subscriptions only
# -----------------------------
cat > scripts/preflight.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "=== Preflight (subscriptions only) ==="

# Fail closed if any API keys are set
deny=(OPENAI_API_KEY OPENAI_KEY CODEX_API_KEY ANTHROPIC_API_KEY ANTHROPIC_KEY)
for v in "${deny[@]}"; do
  if [[ -n "${!v:-}" ]]; then
    echo "❌ $v is set. Unset it to avoid API billing."
    exit 2
  fi
done

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing: $1"; exit 2; }; }
need git
need tmux
need codex
need claude
need bash

# Must be logged into Codex subscription
if ! codex login status >/dev/null 2>&1; then
  echo "❌ Codex is not logged in. Run: codex login"
  exit 2
fi

echo "✅ Preflight OK."
EOF
chmod +x scripts/preflight.sh

# -----------------------------
# 4) Codex runner (matches YOUR CLI: codex -a never exec ...)
# -----------------------------
cat > scripts/agent.codex.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PROMPT_FILE=""
LOG_FILE=""
MODEL_PRIMARY="${CODEX_MODEL_PRIMARY:-gpt-5.3-codex-spark}"
MODEL_FALLBACK="${CODEX_MODEL_FALLBACK:-gpt-5.3-codex}"
MODEL_FALLBACK2="${CODEX_MODEL_FALLBACK2:-gpt-5.2-codex}"

CODEX_APPROVAL="${CODEX_APPROVAL:-never}"           # you want fully autonomous
CODEX_SANDBOX="${CODEX_SANDBOX:-workspace-write}"
CODEX_REASONING="${CODEX_REASONING:-xhigh}"
CODEX_NETWORK="${CODEX_NETWORK:-true}"

usage() {
  echo "Usage: $0 --prompt <file> --log <file>"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) PROMPT_FILE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

[[ -f "$PROMPT_FILE" ]] || { echo "❌ prompt file missing: $PROMPT_FILE"; exit 2; }
mkdir -p "$(dirname "$LOG_FILE")"

# Enforce subscription-only
unset OPENAI_API_KEY OPENAI_KEY CODEX_API_KEY || true

PROMPT="$(cat "$PROMPT_FILE")"

# Detect whether -c is global or exec-level (best-effort, no token cost)
HAS_GLOBAL_CONFIG=false
if codex --help 2>&1 | grep -qE '\-c|--config'; then HAS_GLOBAL_CONFIG=true; fi

run_one () {
  local model="$1"
  echo "=== Codex model=$model approval=$CODEX_APPROVAL sandbox=$CODEX_SANDBOX reasoning=$CODEX_REASONING net=$CODEX_NETWORK ===" | tee -a "$LOG_FILE"

  if $HAS_GLOBAL_CONFIG; then
    # IMPORTANT: approval is GLOBAL on your machine: `codex -a never exec ...`
    codex -a "$CODEX_APPROVAL" \
      -c "forced_login_method=chatgpt" \
      -c "model_reasoning_effort=$CODEX_REASONING" \
      -c "model_reasoning_summary=concise" \
      -c "sandbox_workspace_write.network_access=$CODEX_NETWORK" \
      exec --ephemeral --model "$model" --sandbox "$CODEX_SANDBOX" "$PROMPT" 2>&1 | tee -a "$LOG_FILE"
  else
    # If config flag isn't available, still run (but you asked xhigh always; this is the only safe fallback).
    codex -a "$CODEX_APPROVAL" \
      exec --ephemeral --model "$model" --sandbox "$CODEX_SANDBOX" "$PROMPT" 2>&1 | tee -a "$LOG_FILE"
  fi
}

set +e
run_one "$MODEL_PRIMARY"
rc="${PIPESTATUS[0]}"
set -e

if [[ "$rc" -ne 0 ]]; then
  echo "⚠️ primary failed rc=$rc, trying fallback: $MODEL_FALLBACK" | tee -a "$LOG_FILE"
  set +e; run_one "$MODEL_FALLBACK"; rc="${PIPESTATUS[0]}"; set -e
fi

if [[ "$rc" -ne 0 ]]; then
  echo "⚠️ fallback failed rc=$rc, trying fallback2: $MODEL_FALLBACK2" | tee -a "$LOG_FILE"
  run_one "$MODEL_FALLBACK2"
fi
EOF
chmod +x scripts/agent.codex.sh

# -----------------------------
# 5) Claude runner (subscription only, no env API key)
# -----------------------------
cat > scripts/agent.claude.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PROMPT_FILE=""
LOG_FILE=""
MODEL="${CLAUDE_MODEL:-opusplan}"
FALLBACK="${CLAUDE_FALLBACK:-sonnet}"

usage(){ echo "Usage: $0 --prompt <file> --log <file> [--model <model>]"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) PROMPT_FILE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    *) usage; exit 2 ;;
  esac
done

[[ -f "$PROMPT_FILE" ]] || { echo "❌ prompt file missing: $PROMPT_FILE"; exit 2; }
mkdir -p "$(dirname "$LOG_FILE")"

# Enforce subscription-only
unset ANTHROPIC_API_KEY ANTHROPIC_KEY || true

PROMPT="$(cat "$PROMPT_FILE")"

echo "=== Claude model=$MODEL (fallback=$FALLBACK) ===" | tee -a "$LOG_FILE"
claude --model "$MODEL" --fallback-model "$FALLBACK" -p --dangerously-skip-permissions \
  --output-format text \
  "$PROMPT" 2>&1 | tee -a "$LOG_FILE"
EOF
chmod +x scripts/agent.claude.sh

# -----------------------------
# 6) World-class prompts (exact tech choices + strong constraints)
# -----------------------------
cat > prompts/10_scaffold.md <<'EOF'
# LANE 10 — SCAFFOLD (Codex Spark xhigh)

Goal: Create the baseline **TypeScript monorepo** skeleton for the Factory OS that other lanes build on, with minimal conflicts.

Hard constraints:
- Subscription-only. Never require API keys.
- TypeScript-first.
- Keep root config changes here; other lanes should not touch root configs unless absolutely needed.

Deliverables:
1) Monorepo setup:
   - pnpm workspace
   - turbo (optional but preferred)
   - root scripts: dev/build/test/typecheck/lint
2) apps:
   - apps/api: Fastify TS placeholder server with DDD folder layout (empty modules ok)
   - apps/web: Next.js placeholder that builds
3) packages:
   - packages/contracts: Zod schemas for Event/Run/Product (can be minimal)
   - packages/evals: placeholder package for scenario gate (lane 40 will implement)
4) Observability baseline:
   - create `packages/observability` with OpenTelemetry init stub (no external services required)
5) Developer UX:
   - README.md quickstart that says: pnpm i; pnpm dev
   - .gitignore includes runs/, data/, .worktrees/

Definition of done:
- `pnpm -w i` succeeds
- `pnpm -w typecheck` succeeds
- `pnpm -w build` succeeds
- Commit: "lane: scaffold"
EOF

cat > prompts/20_api.md <<'EOF'
# LANE 20 — API CONTROL PLANE (Codex Spark xhigh)

Scope: only edit `apps/api/**` and (if required) `packages/contracts/**`.

Goal: Implement the Factory control plane API in **Fastify + TypeScript** with DDD layout.

Required DDD layout:
apps/api/src/
  domain/
  application/
  infrastructure/
  interfaces/http/
  tests/

Features:
1) Products registry (local-first):
   - store in SQLite at `data/factory.db`
   - endpoints:
     - GET /api/products
     - POST /api/products  {name, repoPath, stackId}
2) Runs:
   - POST /api/products/:id/runs  {pipelineId, specText}
   - GET  /api/runs/:runId
   - POST /api/runs/:runId/stop
   - POST /api/runs/:runId/resume
3) SSE live events:
   - GET /api/runs/:runId/events  (SSE)
   - Emit structured events at least once/sec:
     - runStatus snapshot
     - new log lines from run directory (tail)
4) Process orchestration (v1):
   - For now, run pipelines by spawning a local CLI command that writes into runs/<runId>/...
   - Provide an abstraction in infrastructure: `RunExecutor`.
   - Must support stop/resume via PID tracking and signals.

Tests:
- At least unit tests for:
  - Run state transitions
  - SSE framing (basic)

Definition of done:
- `pnpm -C apps/api test` passes
- `pnpm -C apps/api typecheck` passes
- Commit: "lane: api"
EOF

cat > prompts/30_webui.md <<'EOF'
# LANE 30 — WEBUI (Codex Spark xhigh)

Scope: only edit `apps/web/**` and shared types if needed.

Goal: Next.js WebUI that shows runs in real time.

Pages:
- / (products list + create product)
- /products/[id] (product detail + start run form)
- /runs/[runId] (live run console)

Live run console must show:
- status badge (running/stopped/succeeded/failed)
- timeline view of stages (can be stubbed from events)
- log stream (SSE)
- stop/resume buttons
- links to run artifacts folder path (runs/<runId>/...)

Constraints:
- Use EventSource SSE from API.
- Keep UI minimal but functional.

Tests:
- One Playwright smoke test: UI loads / and lists products (mock if needed)

Definition of done:
- `pnpm -C apps/web build` passes
- `pnpm -C apps/web test` passes (unit + e2e if configured)
- Commit: "lane: webui"
EOF

cat > prompts/40_evals.md <<'EOF'
# LANE 40 — EVALS + STAT GATE (Codex Spark xhigh)

Scope: only edit `packages/evals/**` (and types in packages/contracts if needed).

Goal: Implement the evaluation harness for the Validation Constraint.

Deliverables:
1) Scenario format (v1):
   - JSON-based scenario files: {name, command, timeoutSec, expect: {exitCode, contains?}}
   - Runner executes scenarios and returns pass/fail + evidence.
2) Statistical acceptance:
   - Implement Clopper–Pearson lower bound for binomial pass rate.
   - Gate passes if lowerBound(alpha=0.05) >= threshold (default 0.98).
3) Tournament helper:
   - sequential halving: evaluate K candidates on small subset, keep top half, expand budget, repeat.
4) CLI:
   - `pnpm -C packages/evals evals:run --scenarios <dir> --alpha 0.05 --threshold 0.98`
   - writes eval_report.json

Tests:
- unit tests for Clopper–Pearson (known values)
- unit tests for scenario runner

Definition of done:
- `pnpm -C packages/evals test` passes
- Commit: "lane: evals"
EOF

cat > prompts/50_pipelines_templates.md <<'EOF'
# LANE 50 — PIPELINES + TEMPLATES (Claude OpusPlan → Sonnet executes)

Scope: pipelines/** templates/** skills/** (avoid touching apps/api and apps/web).

Goal: Create default pipelines + templates that reduce drift and scale product output.

Deliverables:
1) model-matrix.json exists (root) per SPEC.
2) pipelines (DOT-like or JSON DAG) and a minimal runner contract:
   - pipelines/self_check.dot
   - pipelines/new_product.dot
   - pipelines/add_feature.dot
   - pipelines/fix_bug.dot
   Each pipeline emits stage events + artifacts under runs/<runId>/...
3) templates:
   - templates/ts-next-convex-vercel (default)
   - templates/ts-next-supabase-vercel
   - templates/ts-next-fastify-fly (optional skeleton)
4) skills:
   - skills/write_holdout_scenarios (explains holdouts outside repo)
   - skills/vercel_deploy_dryrun
   - skills/factory_observability

Definition of done:
- Each pipeline has docs and can be validated (even if runner is stubbed).
- Commit: "lane: pipelines"
EOF

cat > prompts/60_integrate.md <<'EOF'
# LANE 60 — INTEGRATE (Codex, merge sheriff)

You run on the main branch workspace.

Goal: Merge all lanes and make the repo green.

Wait until these DONE files exist in $SF_RUN_DIR:
- 10_scaffold.done
- 20_api.done
- 30_webui.done
- 40_evals.done
- 50_pipelines.done
- 70_review.done (optional but merge if exists)

Then:
1) Merge lane branches into current branch in this order:
   - lane/scaffold
   - lane/api
   - lane/evals
   - lane/pipelines
   - lane/webui
   - lane/review (if exists)
2) Resolve conflicts minimally.
3) Run:
   - pnpm -w i
   - pnpm -w typecheck
   - pnpm -w test
   - pnpm -w build
4) Fix failures until green.
5) Write runs/<runId>/INTEGRATION_SUMMARY.md explaining how to run locally.
6) Commit: "chore: integrate lanes"

EOF

cat > prompts/70_opus_review.md <<'EOF'
# LANE 70 — REVIEW/HARDEN (Claude Opus)

Scope: you can change anything, but keep diffs small and high leverage.

Goal: Hardening pass focused on:
- subscription-only invariants (no API keys)
- correctness
- observability events
- testability
- minimal drift

Deliverables:
- docs/review_findings.md (prioritized)
- implement top 3 fixes directly (commit)
- write DONE marker instruction for integrator: create $SF_RUN_DIR/70_review.done at end.

When finished, print: "REVIEW DONE" and ensure your branch commits are ready to merge.
EOF

# -----------------------------
# 7) Swarm tmux script (bash -lc to avoid zoxide)
# -----------------------------
cat > scripts/swarm.tmux.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
./scripts/preflight.sh

# Ensure git + initial commit (worktrees need it)
if ! git rev-parse HEAD >/dev/null 2>&1; then
  echo "❌ No git commit found. Run ./scripts/install_factory_pack.sh again."
  exit 2
fi

BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$ROOT/runs/$RUN_ID"
mkdir -p "$RUN_DIR"
export SF_RUN_DIR="$RUN_DIR"
export SF_ROOT="$ROOT"

# Spark-first by default (your request)
export CODEX_MODEL_PRIMARY="${CODEX_MODEL_PRIMARY:-gpt-5.3-codex-spark}"
export CODEX_MODEL_FALLBACK="${CODEX_MODEL_FALLBACK:-gpt-5.3-codex}"
export CODEX_MODEL_FALLBACK2="${CODEX_MODEL_FALLBACK2:-gpt-5.2-codex}"

export CLAUDE_PIPELINES_MODEL="${CLAUDE_PIPELINES_MODEL:-opusplan}"
export CLAUDE_REVIEW_MODEL="${CLAUDE_REVIEW_MODEL:-opus}"

mkdir -p "$ROOT/.worktrees"

# Require prompts
for f in prompts/10_scaffold.md prompts/20_api.md prompts/30_webui.md prompts/40_evals.md prompts/50_pipelines_templates.md prompts/60_integrate.md prompts/70_opus_review.md; do
  [[ -f "$f" ]] || { echo "❌ Missing $f"; exit 2; }
done

# Create/reset worktrees from base branch
mk_wt () {
  local name="$1"
  local branch="lane/$name"
  local dir="$ROOT/.worktrees/$name"
  rm -rf "$dir" >/dev/null 2>&1 || true
  git worktree add -f -B "$branch" "$dir" "$BASE_BRANCH" >/dev/null
}

mk_wt scaffold
mk_wt api
mk_wt webui
mk_wt evals
mk_wt pipelines
mk_wt review

SESSION="sf-$RUN_ID"
tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -n swarm

# 7 panes in one window
for _ in 1 2 3 4 5 6; do tmux split-window -t "$SESSION":0 -v; done
tmux select-layout -t "$SESSION":0 tiled

# Helper: always run in bash -lc to avoid user shell aliases (zoxide)
send () {
  local pane="$1"; shift
  local cmd="$*"
  tmux send-keys -t "$SESSION":0."$pane" "bash -lc '$cmd'" C-m
}

# Codex lanes (Spark xhigh)
send 0 "cd \"$ROOT/.worktrees/scaffold\" && \"$ROOT/scripts/agent.codex.sh\" --prompt \"$ROOT/prompts/10_scaffold.md\" --log \"$RUN_DIR/10_scaffold.log\" && echo DONE > \"$RUN_DIR/10_scaffold.done\""
send 1 "cd \"$ROOT/.worktrees/api\"      && \"$ROOT/scripts/agent.codex.sh\" --prompt \"$ROOT/prompts/20_api.md\"      --log \"$RUN_DIR/20_api.log\"      && echo DONE > \"$RUN_DIR/20_api.done\""
send 2 "cd \"$ROOT/.worktrees/webui\"    && \"$ROOT/scripts/agent.codex.sh\" --prompt \"$ROOT/prompts/30_webui.md\"    --log \"$RUN_DIR/30_webui.log\"    && echo DONE > \"$RUN_DIR/30_webui.done\""
send 3 "cd \"$ROOT/.worktrees/evals\"    && \"$ROOT/scripts/agent.codex.sh\" --prompt \"$ROOT/prompts/40_evals.md\"    --log \"$RUN_DIR/40_evals.log\"    && echo DONE > \"$RUN_DIR/40_evals.done\""

# Claude pipelines (opusplan -> sonnet execution)
send 4 "cd \"$ROOT/.worktrees/pipelines\" && CLAUDE_MODEL=\"$CLAUDE_PIPELINES_MODEL\" \"$ROOT/scripts/agent.claude.sh\" --prompt \"$ROOT/prompts/50_pipelines_templates.md\" --log \"$RUN_DIR/50_pipelines.log\" && echo DONE > \"$RUN_DIR/50_pipelines.done\""

# Claude Opus review lane
send 5 "cd \"$ROOT/.worktrees/review\" && CLAUDE_MODEL=\"$CLAUDE_REVIEW_MODEL\" \"$ROOT/scripts/agent.claude.sh\" --prompt \"$ROOT/prompts/70_opus_review.md\" --log \"$RUN_DIR/70_opus_review.log\" && echo DONE > \"$RUN_DIR/70_review.done\""

# Integrator lane on ROOT (merges + fixes + green)
send 6 "cd \"$ROOT\" && \"$ROOT/scripts/agent.codex.sh\" --prompt \"$ROOT/prompts/60_integrate.md\" --log \"$RUN_DIR/60_integrate.log\" && echo DONE > \"$RUN_DIR/60_integrate.done\""

# Logs window
tmux new-window -t "$SESSION" -n logs
tmux send-keys -t "$SESSION":logs.0 "bash -lc 'cd \"$RUN_DIR\" && ls -la && tail -n 200 -f *.log'" C-m

echo "✅ Swarm started: tmux attach -t $SESSION"
echo "Run dir: $RUN_DIR"
tmux attach -t "$SESSION"
EOF
chmod +x scripts/swarm.tmux.sh

# Commit the pack itself so worktrees are stable
git add -A
git commit -m "chore: install factory pack" >/dev/null 2>&1 || true

echo ""
echo "✅ Pack installed."
echo "Next: ./scripts/swarm.tmux.sh"
echo "Base branch: $BASE_BRANCH"
