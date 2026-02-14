#!/usr/bin/env bash
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

./scripts/preflight.subscriptions_only.sh

required_prompts=(
  prompts/10_scaffold.md
  prompts/20_api.md
  prompts/30_webui.md
  prompts/40_evals.md
  prompts/50_pipelines_templates.md
  prompts/60_integrate.md
  prompts/70_opus_review.md
)
for p in "${required_prompts[@]}"; do
  if [[ ! -f "$p" ]]; then
    echo "Missing $p"
    echo "Run: ./scripts/install_factory_pack.sh"
    exit 2
  fi
done

RUN_ID="$(date +%Y%m%d-%H%M%S)"
RUN_DIR="$ROOT/runs/$RUN_ID"
mkdir -p "$RUN_DIR"

echo "run_id=$RUN_ID" > "$RUN_DIR/meta.env"
echo "root=$ROOT" >> "$RUN_DIR/meta.env"
echo "git_rev=$(git rev-parse HEAD)" >> "$RUN_DIR/meta.env"

export SF_RUN_DIR="$RUN_DIR"
export SF_ROOT="$ROOT"

# Models (subscription-only)
export CODEX_MODEL_PRIMARY="${CODEX_MODEL_PRIMARY:-gpt-5.3-codex-spark}"
export CODEX_MODEL_FALLBACK="${CODEX_MODEL_FALLBACK:-gpt-5.3-codex}"
export CODEX_MODEL_FALLBACK2="${CODEX_MODEL_FALLBACK2:-gpt-5.2-codex}"

export CLAUDE_MODEL_PRIMARY_PIPELINES="${CLAUDE_MODEL_PRIMARY_PIPELINES:-opusplan}"
export CLAUDE_MODEL_PRIMARY_REVIEW="${CLAUDE_MODEL_PRIMARY_REVIEW:-opus}"
export CLAUDE_MODEL_FALLBACK="${CLAUDE_MODEL_FALLBACK:-sonnet}"

# Worktrees per lane
make_wt() {
  local name="$1"
  local branch="lane/$name"
  local dir="$ROOT/.worktrees/$name"
  mkdir -p "$ROOT/.worktrees"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    :
  else
    git branch "$branch" >/dev/null 2>&1 || true
  fi
  if [[ -d "$dir/.git" || -d "$dir" ]]; then
    rm -rf "$dir"
  fi
  git worktree add -f "$dir" "$branch" >/dev/null
  echo "$dir"
}

WT_SCAFFOLD="$(make_wt scaffold)"
WT_API="$(make_wt api)"
WT_WEBUI="$(make_wt webui)"
WT_EVALS="$(make_wt evals)"
WT_PIPELINES="$(make_wt pipelines)"
WT_REVIEW="$(make_wt review)"

SESSION="sf-$RUN_ID"

tmux new-session -d -s "$SESSION" -n "scaffold"

# Pane layout: 2 rows x 4 cols-ish
tmux split-window -h -t "$SESSION:scaffold"
tmux split-window -v -t "$SESSION:scaffold.0"
tmux split-window -v -t "$SESSION:scaffold.1"
tmux select-layout -t "$SESSION:scaffold" tiled >/dev/null

# Add more windows for review + integrator
tmux new-window -t "$SESSION" -n "review"
tmux new-window -t "$SESSION" -n "integrator"

# Helper to run lane in a pane
codex_lane() {
  local pane="$1"; shift
  local wt="$1"; shift
  local prompt="$1"; shift
  local log="$1"; shift
  local done="$1"; shift

  tmux send-keys -t "$SESSION:scaffold.$pane" \
    "cd \"$wt\" && export SF_RUN_DIR=\"$RUN_DIR\" SF_ROOT=\"$ROOT\" && \"$ROOT/scripts/agent.codex.sub.sh\" --prompt \"$ROOT/$prompt\" --log \"$RUN_DIR/$log\" && echo DONE > \"$RUN_DIR/$done\"" C-m
}

claude_lane() {
  local target="$1"; shift
  local wt="$1"; shift
  local model="$1"; shift
  local prompt="$1"; shift
  local log="$1"; shift
  local done="$1"; shift

  tmux send-keys -t "$target" \
    "cd \"$wt\" && export SF_RUN_DIR=\"$RUN_DIR\" SF_ROOT=\"$ROOT\" && CLAUDE_MODEL_PRIMARY=\"$model\" \"$ROOT/scripts/agent.claude.sub.sh\" --prompt \"$ROOT/$prompt\" --log \"$RUN_DIR/$log\" && echo DONE > \"$RUN_DIR/$done\"" C-m
}

# Run lanes (parallel)
codex_lane 0 "$WT_SCAFFOLD" "prompts/10_scaffold.md" "10_scaffold.log" "10_scaffold.done"
codex_lane 1 "$WT_API"      "prompts/20_api.md"      "20_api.log"      "20_api.done"
codex_lane 2 "$WT_WEBUI"    "prompts/30_webui.md"    "30_webui.log"    "30_webui.done"
codex_lane 3 "$WT_EVALS"    "prompts/40_evals.md"    "40_evals.log"    "40_evals.done"

# Claude pipelines (opusplan) in review window pane 0
tmux split-window -h -t "$SESSION:review"
tmux select-layout -t "$SESSION:review" even-horizontal >/dev/null
claude_lane "$SESSION:review.0" "$WT_PIPELINES" "$CLAUDE_MODEL_PRIMARY_PIPELINES" "prompts/50_pipelines_templates.md" "50_pipelines.log" "50_pipelines.done"

# Claude reviewer (opus) in review window pane 1
claude_lane "$SESSION:review.1" "$WT_REVIEW" "$CLAUDE_MODEL_PRIMARY_REVIEW" "prompts/70_opus_review.md" "70_opus_review.log" "70_opus_review.done"

# Integrator (Codex) runs on main worktree (ROOT)
tmux send-keys -t "$SESSION:integrator.0" \
  "cd \"$ROOT\" && export SF_RUN_DIR=\"$RUN_DIR\" SF_ROOT=\"$ROOT\" && \"$ROOT/scripts/agent.codex.sub.sh\" --prompt \"$ROOT/prompts/60_integrate.md\" --log \"$RUN_DIR/60_integrate.log\" && echo DONE > \"$RUN_DIR/60_integrate.done\"" C-m

echo "✅ Swarm started in tmux session: $SESSION"
echo "Run dir: $RUN_DIR"
echo "Attach with: tmux attach -t $SESSION"
tmux attach -t "$SESSION"
