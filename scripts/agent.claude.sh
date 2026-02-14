#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:?model required}"        # opus | sonnet | opusplan | full model name
PROMPT_FILE="${2:?prompt_file required}"
LOGFILE="${3:?logfile required}"

# Effort levels for Opus 4.6 inside Claude Code: low|medium|high (default).
# (Claude Code does not expose "max" effort via env var as of Feb 2026.)
export CLAUDE_CODE_EFFORT_LEVEL="${CLAUDE_CODE_EFFORT_LEVEL:-high}"

PROMPT="$(cat "$PROMPT_FILE")"

echo ">>> claude --model $MODEL -p --dangerously-skip-permissions (prompt: $PROMPT_FILE)" | tee "$LOGFILE"
claude --model "$MODEL" -p --dangerously-skip-permissions \
  --output-format text \
  "$PROMPT" 2>&1 | tee -a "$LOGFILE"
