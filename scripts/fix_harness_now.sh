#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$ROOT"

mkdir -p scripts runs prompts data .worktrees

# -------------------------
# .gitignore hardening
# -------------------------
if [[ ! -f .gitignore ]]; then touch .gitignore; fi
grep -q '^runs/$' .gitignore || cat >> .gitignore <<'EOF'

# factory artifacts
runs/
data/
.worktrees/

# pnpm artifacts (just in case)
.pnpm-store/
**/.pnpm-store/
EOF

# -------------------------
# Preflight: also warn about broken ~/.agents/skills symlinks (Codex noise)
# -------------------------
cat > scripts/preflight.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

echo "=== Preflight (subscriptions only) ==="

deny=(OPENAI_API_KEY OPENAI_KEY CODEX_API_KEY ANTHROPIC_API_KEY ANTHROPIC_KEY)
for v in "${deny[@]}"; do
  if [[ -n "${!v:-}" ]]; then
    echo "❌ $v is set. Unset it (subscription-only)."
    exit 2
  fi
done

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing: $1"; exit 2; }; }
need git
need tmux
need codex
need claude
need bash

# Codex must be logged in (subscription auth)
if ! codex login status >/dev/null 2>&1; then
  echo "❌ Codex not logged in. Run: codex login"
  exit 2
fi

# Optional: warn about broken skills symlinks (your log shows this)
if [[ -d "$HOME/.agents/skills" ]]; then
  broken="$(find "$HOME/.agents/skills" -xtype l 2>/dev/null | head -n 1 || true)"
  if [[ -n "${broken:-}" ]]; then
    echo "⚠️  Broken skills symlink detected under ~/.agents/skills"
    echo "    Example: $broken"
    echo "    Fix: find ~/.agents/skills -xtype l -delete"
  fi
fi

echo "✅ Preflight OK."
EOF
chmod +x scripts/preflight.sh

# -------------------------
# Sandbox env: make pnpm writable inside Codex sandbox
# -------------------------
cat > scripts/env_sandbox.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${SF_RUN_DIR:?SF_RUN_DIR must be set}"

export XDG_DATA_HOME="${XDG_DATA_HOME:-$SF_RUN_DIR/.xdg-data}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$SF_RUN_DIR/.xdg-cache}"
export npm_config_cache="${npm_config_cache:-$SF_RUN_DIR/.npm-cache}"

# pnpm specific
export PNPM_HOME="${PNPM_HOME:-$SF_RUN_DIR/.pnpm-home}"
export PNPM_STORE_DIR="${PNPM_STORE_DIR:-$SF_RUN_DIR/.pnpm-store}"

mkdir -p "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$npm_config_cache" "$PNPM_HOME" "$PNPM_STORE_DIR"
EOF
chmod +x scripts/env_sandbox.sh

# -------------------------
# Lane runners: always write rc + done, never silently skip
# -------------------------
cat > scripts/run_lane_codex.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LANE="${1:?lane key required}"           # e.g. 10_scaffold
WORKDIR="${2:?workdir required}"
PROMPT="${3:?prompt path required}"

: "${SF_RUN_DIR:?SF_RUN_DIR must be set}"
: "${SF_ROOT:?SF_ROOT must be set}"

LOG="$SF_RUN_DIR/${LANE}.log"
RCF="$SF_RUN_DIR/${LANE}.rc"
DONE="$SF_RUN_DIR/${LANE}.done"

mkdir -p "$SF_RUN_DIR"
: > "$LOG"

cd "$WORKDIR"
source "$SF_ROOT/scripts/env_sandbox.sh"

set +e
"$SF_ROOT/scripts/agent.codex.sh" --prompt "$PROMPT" --log "$LOG"
rc=$?
set -e

echo "$rc" > "$RCF"
if [[ "$rc" -eq 0 ]]; then echo DONE > "$DONE"; fi
exit "$rc"
EOF
chmod +x scripts/run_lane_codex.sh

cat > scripts/run_lane_claude.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

LANE="${1:?lane key required}"           # e.g. 50_pipelines
WORKDIR="${2:?workdir required}"
PROMPT="${3:?prompt path required}"
MODEL="${4:?model required}"             # opusplan | opus | sonnet

: "${SF_RUN_DIR:?SF_RUN_DIR must be set}"
: "${SF_ROOT:?SF_ROOT must be set}"

LOG="$SF_RUN_DIR/${LANE}.log"
RCF="$SF_RUN_DIR/${LANE}.rc"
DONE="$SF_RUN_DIR/${LANE}.done"

mkdir -p "$SF_RUN_DIR"
: > "$LOG"

cd "$WORKDIR"
source "$SF_ROOT/scripts/env_sandbox.sh"

# subscription-only
unset ANTHROPIC_API_KEY ANTHROPIC_KEY || true

set +e
CLAUDE_MODEL="$MODEL" "$SF_ROOT/scripts/agent.claude.sh" --prompt "$PROMPT" --log "$LOG"
rc=$?
set -e

echo "$rc" > "$RCF"
if [[ "$rc" -eq 0 ]]; then echo DONE > "$DONE"; fi
exit "$rc"
EOF
chmod +x scripts/run_lane_claude.sh

# -------------------------
# Integrator runner: HARD GATE in shell (no LLM decision)
# -------------------------
cat > scripts/run_integrator.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${SF_RUN_DIR:?SF_RUN_DIR must be set}"
: "${SF_ROOT:?SF_ROOT must be set}"

source "$SF_ROOT/scripts/env_sandbox.sh"

REQ=(10_scaffold 20_api 30_webui 40_evals 50_pipelines)
OPT=(70_review)

timeout="${INTEGRATOR_WAIT_TIMEOUT_SECS:-7200}"   # 2h default
deadline=$((SECONDS + timeout))

echo "==> Integrator waiting for required lanes: ${REQ[*]}"
while true; do
  missing=0
  for l in "${REQ[@]}"; do
    [[ -f "$SF_RUN_DIR/${l}.rc" ]] || missing=1
  done
  [[ "$missing" -eq 0 ]] && break

  if [[ "$SECONDS" -ge "$deadline" ]]; then
    echo "❌ Timeout waiting for lanes. Check logs in: $SF_RUN_DIR"
    exit 3
  fi
  sleep 2
done

# Fail fast if any required lane failed
for l in "${REQ[@]}"; do
  rc="$(cat "$SF_RUN_DIR/${l}.rc" || echo 999)"
  if [[ "$rc" -ne 0 ]]; then
    echo "❌ Lane $l failed (rc=$rc). See $SF_RUN_DIR/${l}.log"
    exit 4
  fi
done

# Optional review lane check (doesn't block)
for l in "${OPT[@]}"; do
  if [[ -f "$SF_RUN_DIR/${l}.rc" ]]; then
    rc="$(cat "$SF_RUN_DIR/${l}.rc" || echo 999)"
    if [[ "$rc" -ne 0 ]]; then
      echo "⚠️ Optional lane $l failed (rc=$rc). Continuing. See $SF_RUN_DIR/${l}.log"
    fi
  fi
done

echo "✅ Required lanes succeeded. Launching Codex integrator…"
unset OPENAI_API_KEY OPENAI_KEY CODEX_API_KEY || true

"$SF_ROOT/scripts/agent.codex.sh" \
  --prompt "$SF_ROOT/prompts/60_integrate.md" \
  --log "$SF_RUN_DIR/60_integrate.log"

rc=$?
echo "$rc" > "$SF_RUN_DIR/60_integrate.rc"
if [[ "$rc" -eq 0 ]]; then echo DONE > "$SF_RUN_DIR/60_integrate.done"; fi
exit "$rc"
EOF
chmod +x scripts/run_integrator.sh

# -------------------------
# Swarm: one tmux window per lane (no panes)
# -------------------------
cat > scripts/swarm.tmux.sh <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

./scripts/preflight.sh

# Require prompts (you already have them)
req=(
  prompts/10_scaffold.md
  prompts/20_api.md
  prompts/30_webui.md
  prompts/40_evals.md
  prompts/50_pipelines_templates.md
  prompts/60_integrate.md
  prompts/70_opus_review.md
)
for f in "${req[@]}"; do
  [[ -f "$f" ]] || { echo "❌ Missing $f"; exit 2; }
done

BASE_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$ROOT/runs/$RUN_ID"
mkdir -p "$RUN_DIR"

export SF_RUN_DIR="$RUN_DIR"
export SF_ROOT="$ROOT"

# Worktrees
mk_wt () {
  local name="$1"
  local branch="lane/$name"
  local dir="$ROOT/.worktrees/$name"
  rm -rf "$dir" >/dev/null 2>&1 || true
  git worktree add -f -B "$branch" "$dir" "$BASE_BRANCH" >/dev/null
  echo "$dir"
}

WT_SCAFFOLD="$(mk_wt scaffold)"
WT_API="$(mk_wt api)"
WT_WEBUI="$(mk_wt webui)"
WT_EVALS="$(mk_wt evals)"
WT_PIPELINES="$(mk_wt pipelines)"
WT_REVIEW="$(mk_wt review)"

SESSION="sf-$RUN_ID"
tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -n scaffold

send_cmd() {
  local target="$1"; shift
  local cmd="$*"
  tmux send-keys -t "$target" "bash -lc $(printf %q "$cmd")" C-m
}

# Defaults (your requirement)
export CODEX_MODEL_PRIMARY="${CODEX_MODEL_PRIMARY:-gpt-5.3-codex-spark}"
export CODEX_MODEL_FALLBACK="${CODEX_MODEL_FALLBACK:-gpt-5.3-codex}"
export CODEX_MODEL_FALLBACK2="${CODEX_MODEL_FALLBACK2:-gpt-5.2-codex}"

export CLAUDE_PIPELINES_MODEL="${CLAUDE_PIPELINES_MODEL:-opusplan}"
export CLAUDE_REVIEW_MODEL="${CLAUDE_REVIEW_MODEL:-opus}"

# Window: scaffold (Codex)
send_cmd "$SESSION:scaffold" \
  "export SF_RUN_DIR=\"$RUN_DIR\" SF_ROOT=\"$ROOT\"; cd \"$WT_SCAFFOLD\"; $ROOT/scripts/run_lane_codex.sh 10_scaffold \"$WT_SCAFFOLD\" \"$ROOT/prompts/10_scaffold.md\""

# Window: api
tmux new-window -t "$SESSION" -n api
send_cmd "$SESSION:api" \
  "export SF_RUN_DIR=\"$RUN_DIR\" SF_ROOT=\"$ROOT\"; cd \"$WT_API\"; $ROOT/scripts/run_lane_codex.sh 20_api \"$WT_API\" \"$ROOT/prompts/20_api.md\""

# Window: webui
tmux new-window -t "$SESSION" -n webui
send_cmd "$SESSION:webui" \
  "export SF_RUN_DIR=\"$RUN_DIR\" SF_ROOT=\"$ROOT\"; cd \"$WT_WEBUI\"; $ROOT/scripts/run_lane_codex.sh 30_webui \"$WT_WEBUI\" \"$ROOT/prompts/30_webui.md\""

# Window: evals
tmux new-window -t "$SESSION" -n evals
send_cmd "$SESSION:evals" \
  "export SF_RUN_DIR=\"$RUN_DIR\" SF_ROOT=\"$ROOT\"; cd \"$WT_EVALS\"; $ROOT/scripts/run_lane_codex.sh 40_evals \"$WT_EVALS\" \"$ROOT/prompts/40_evals.md\""

# Window: pipelines (Claude opusplan)
tmux new-window -t "$SESSION" -n pipelines
send_cmd "$SESSION:pipelines" \
  "export SF_RUN_DIR=\"$RUN_DIR\" SF_ROOT=\"$ROOT\"; cd \"$WT_PIPELINES\"; $ROOT/scripts/run_lane_claude.sh 50_pipelines \"$WT_PIPELINES\" \"$ROOT/prompts/50_pipelines_templates.md\" \"$CLAUDE_PIPELINES_MODEL\""

# Window: review (Claude opus)
tmux new-window -t "$SESSION" -n review
send_cmd "$SESSION:review" \
  "export SF_RUN_DIR=\"$RUN_DIR\" SF_ROOT=\"$ROOT\"; cd \"$WT_REVIEW\"; $ROOT/scripts/run_lane_claude.sh 70_review \"$WT_REVIEW\" \"$ROOT/prompts/70_opus_review.md\" \"$CLAUDE_REVIEW_MODEL\""

# Window: integrator (HARD GATE -> Codex)
tmux new-window -t "$SESSION" -n integrator
send_cmd "$SESSION:integrator" \
  "export SF_RUN_DIR=\"$RUN_DIR\" SF_ROOT=\"$ROOT\"; cd \"$ROOT\"; $ROOT/scripts/run_integrator.sh"

# Window: logs
tmux new-window -t "$SESSION" -n logs
send_cmd "$SESSION:logs" \
  "cd \"$RUN_DIR\"; echo \"--- tailing $RUN_DIR ---\"; ls -la; tail -n 200 -F *.log"

echo "✅ Swarm started. Session: $SESSION"
echo "Run dir: $RUN_DIR"
echo "Attach: tmux attach -t $SESSION"
tmux attach -t "$SESSION"
EOF
chmod +x scripts/swarm.tmux.sh

echo "✅ Harness patched."
echo "Next: ./scripts/swarm.tmux.sh"
