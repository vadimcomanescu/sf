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
