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
