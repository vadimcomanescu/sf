#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v tmux >/dev/null; then
  echo "tmux not installed"; exit 1
fi

SESSION="sf-swarm"

# Create worktrees (disjoint lanes)
mkdir -p .worktrees

create_wt () {
  local name="$1"
  local branch="lane/$name"
  local dir="$ROOT/.worktrees/$name"
  if [ ! -d "$dir" ]; then
    git worktree add "$dir" -b "$branch"
  fi
}

create_wt scaffold
create_wt api
create_wt web
create_wt evals
create_wt pipelines

tmux kill-session -t "$SESSION" 2>/dev/null || true
tmux new-session -d -s "$SESSION" -n swarm

# Pane layout
tmux split-window -h -t "$SESSION":0
tmux split-window -v -t "$SESSION":0.0
tmux split-window -v -t "$SESSION":0.1
tmux split-window -v -t "$SESSION":0.2
tmux select-layout -t "$SESSION":0 tiled

run_codex () {
  local pane="$1"
  local wt="$2"
  local prompt="$3"
  local model="$4"
  tmux send-keys -t "$SESSION":0."$pane" "cd $ROOT/.worktrees/$wt && git status && codex -a never exec --model $model --sandbox workspace-write \"\$(cat $ROOT/prompts/$prompt)\" | tee /tmp/sf-${wt}.out" C-m
}

# Codex lanes (GPT‑5.3‑Codex for deep; Spark for UI iteration)
run_codex 0 scaffold 10_scaffold.md gpt-5.3-codex
run_codex 1 api      20_api.md      gpt-5.3-codex
run_codex 2 web      30_web.md      gpt-5.3-codex-spark
run_codex 3 evals    40_evals.md    gpt-5.3-codex
run_codex 4 pipelines 50_pipelines.md gpt-5.3-codex

tmux select-pane -t "$SESSION":0.0
tmux attach -t "$SESSION"
