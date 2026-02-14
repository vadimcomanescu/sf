#!/usr/bin/env bash
set -euo pipefail

MODEL="${CODEX_MODEL_PRIMARY:-gpt-5.3-codex-spark}"
FALLBACK="${CODEX_MODEL_FALLBACK:-gpt-5.3-codex}"
FALLBACK2="${CODEX_MODEL_FALLBACK2:-gpt-5.2-codex}"
PROMPT_FILE=""
LOG_FILE=""

usage() {
  cat <<USAGE
Usage: $0 --prompt <file> --log <file> [--model <name>] [--fallback <name>] [--fallback2 <name>]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) PROMPT_FILE="$2"; shift 2 ;;
    --log) LOG_FILE="$2"; shift 2 ;;
    --model) MODEL="$2"; shift 2 ;;
    --fallback) FALLBACK="$2"; shift 2 ;;
    --fallback2) FALLBACK2="$2"; shift 2 ;;
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

# Enforce subscription-only
unset OPENAI_API_KEY OPENAI_KEY CODEX_API_KEY || true

run_codex() {
  local m="$1"
  echo "=== Codex exec ($m) ===" | tee -a "$LOG_FILE"
  # IMPORTANT:
  # - use ChatGPT OAuth login (forced_login_method=chatgpt)
  # - reasoning xhigh
  # - ensure Responses wire protocol so reasoning effort is honored
  # - allow network for installs/tests inside workspace-write sandbox
  codex exec \
    --model "$m" \
    --ask-for-approval on-request \
    --sandbox workspace-write \
    -c forced_login_method=chatgpt \
    -c model_providers.openai.wire_api=responses \
    -c model_reasoning_effort=xhigh \
    -c model_reasoning_summary=concise \
    -c sandbox_workspace_write.network_access=true \
    - < "$PROMPT_FILE" 2>&1 | tee -a "$LOG_FILE"
}

if run_codex "$MODEL"; then
  exit 0
fi

echo "⚠️ Codex primary failed; trying fallback: $FALLBACK" | tee -a "$LOG_FILE"
if run_codex "$FALLBACK"; then
  exit 0
fi

echo "⚠️ Codex fallback failed; trying fallback2: $FALLBACK2" | tee -a "$LOG_FILE"
run_codex "$FALLBACK2"
