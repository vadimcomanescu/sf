#!/usr/bin/env bash
set -euo pipefail

MODEL="${1:?model required}"
PROMPT_FILE="${2:?prompt_file required}"
LOGFILE="${3:?logfile required}"

CODEX_APPROVAL="${CODEX_APPROVAL:-never}"             # untrusted|on-failure|on-request|never
CODEX_SANDBOX="${CODEX_SANDBOX:-workspace-write}"     # read-only|workspace-write|danger-full-access
CODEX_REASONING_EFFORT="${CODEX_REASONING_EFFORT:-xhigh}"  # minimal|low|medium|high|xhigh
CODEX_WIRE_API="${CODEX_WIRE_API:-responses}"         # chat|responses
CODEX_NETWORK="${CODEX_NETWORK:-true}"                # allow installs/tests that need network
CODEX_LIVE_SEARCH="${CODEX_LIVE_SEARCH:-true}"        # codex web search: cached vs live

PROMPT="$(cat "$PROMPT_FILE")"

args=(
  exec
  --model "$MODEL"
  --ask-for-approval "$CODEX_APPROVAL"
  --sandbox "$CODEX_SANDBOX"
  --config "model_providers.openai.wire_api=$CODEX_WIRE_API"
  --config "model_reasoning_effort=$CODEX_REASONING_EFFORT"
  --config "sandbox_workspace_write.network_access=$CODEX_NETWORK"
)

if [[ "$CODEX_LIVE_SEARCH" == "true" ]]; then
  args+=(--search)
fi

echo ">>> codex ${args[*]}  (prompt: $PROMPT_FILE)" | tee "$LOGFILE"
codex "${args[@]}" "$PROMPT" 2>&1 | tee -a "$LOGFILE"
