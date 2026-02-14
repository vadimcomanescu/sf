#!/usr/bin/env bash
set -euo pipefail

MODEL="${CLAUDE_MODEL_PRIMARY:-opusplan}"
FALLBACK="${CLAUDE_MODEL_FALLBACK:-sonnet}"
PROMPT_FILE=""
LOG_FILE=""

usage() {
  cat <<USAGE
Usage: $0 --prompt <file> --log <file> [--model <name>] [--fallback <name>]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) PROMPT_FILE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --fallback) FALLBACK="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 2 ;;
  esac
done

if [[ -z "$PROMPT_FILE" || -z "$LOG_FILE" ]]; then
  usage; exit 2
fi
if [[ ! -f "$PROMPT_FILE" ]]; then
  echo "❌ Prompt file not found: $PROMPT_FILE"
  exit 2
fi

# Enforce subscription-only (unset ALL provider keys, not just Anthropic)
unset ANTHROPIC_API_KEY ANTHROPIC_KEY OPENAI_API_KEY OPENAI_KEY CODEX_API_KEY || true

run_claude() {
  local m="$1"
  echo "=== Claude Code (-p) ($m) ===" | tee -a "$LOG_FILE"
  # We pipe the full instruction document into stdin to avoid shell arg limits.
  cat "$PROMPT_FILE" | claude -p \
    "You will receive a full instruction document on stdin. Execute it exactly. Do not ask questions. Work in the current git repo." \
    --model "$m" \
    --fallback-model "$FALLBACK" \
    --output-format text \
    --dangerously-skip-permissions \
    --max-turns 200 \
    2>&1 | tee -a "$LOG_FILE"
}

if run_claude "$MODEL"; then
  exit 0
fi

echo "⚠️ Claude primary failed; retrying with fallback model: $FALLBACK" | tee -a "$LOG_FILE"
CLAUDE_MODEL_PRIMARY="$FALLBACK" run_claude "$FALLBACK"
