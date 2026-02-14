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
