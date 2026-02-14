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
