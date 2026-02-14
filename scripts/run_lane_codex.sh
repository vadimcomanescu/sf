#!/usr/bin/env bash
set -euo pipefail

LANE="${1:?lane key required}"           # e.g. 10_scaffold
WORKDIR="${2:?workdir required}"
PROMPT="${3:?prompt path required}"

: "${SF_RUN_DIR:?SF_RUN_DIR must be set}"
: "${SF_ROOT:?SF_ROOT must be set}"

LOG="$SF_RUN_DIR/${LANE}.log"
RCF="$SF_RUN_DIR/${LANE}.rc"
DONE="$SF_RUN_DIR/${LANE}.done"

mkdir -p "$SF_RUN_DIR"
: > "$LOG"

cd "$WORKDIR"
source "$SF_ROOT/scripts/env_sandbox.sh"

set +e
"$SF_ROOT/scripts/agent.codex.sh" --prompt "$PROMPT" --log "$LOG"
rc=$?
set -e

echo "$rc" > "$RCF"
if [[ "$rc" -eq 0 ]]; then echo DONE > "$DONE"; fi
exit "$rc"
