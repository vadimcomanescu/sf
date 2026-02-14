#!/usr/bin/env bash
set -euo pipefail

: "${SF_RUN_DIR:?SF_RUN_DIR must be set}"
: "${SF_ROOT:?SF_ROOT must be set}"

source "$SF_ROOT/scripts/env_sandbox.sh"

REQ=(10_scaffold 20_api 30_webui 40_evals 50_pipelines)
OPT=(70_review)

timeout="${INTEGRATOR_WAIT_TIMEOUT_SECS:-7200}"   # 2h default
deadline=$((SECONDS + timeout))

echo "==> Integrator waiting for required lanes: ${REQ[*]}"
while true; do
  missing=0
  for l in "${REQ[@]}"; do
    [[ -f "$SF_RUN_DIR/${l}.rc" ]] || missing=1
  done
  [[ "$missing" -eq 0 ]] && break

  if [[ "$SECONDS" -ge "$deadline" ]]; then
    echo "❌ Timeout waiting for lanes. Check logs in: $SF_RUN_DIR"
    exit 3
  fi
  sleep 2
done

# Fail fast if any required lane failed
for l in "${REQ[@]}"; do
  rc="$(cat "$SF_RUN_DIR/${l}.rc" || echo 999)"
  if [[ "$rc" -ne 0 ]]; then
    echo "❌ Lane $l failed (rc=$rc). See $SF_RUN_DIR/${l}.log"
    exit 4
  fi
done

# Optional review lane check (doesn't block)
for l in "${OPT[@]}"; do
  if [[ -f "$SF_RUN_DIR/${l}.rc" ]]; then
    rc="$(cat "$SF_RUN_DIR/${l}.rc" || echo 999)"
    if [[ "$rc" -ne 0 ]]; then
      echo "⚠️ Optional lane $l failed (rc=$rc). Continuing. See $SF_RUN_DIR/${l}.log"
    fi
  fi
done

echo "✅ Required lanes succeeded. Launching Codex integrator…"
unset OPENAI_API_KEY OPENAI_KEY CODEX_API_KEY || true

"$SF_ROOT/scripts/agent.codex.sh" \
  --prompt "$SF_ROOT/prompts/60_integrate.md" \
  --log "$SF_RUN_DIR/60_integrate.log"

rc=$?
echo "$rc" > "$SF_RUN_DIR/60_integrate.rc"
if [[ "$rc" -eq 0 ]]; then echo DONE > "$SF_RUN_DIR/60_integrate.done"; fi
exit "$rc"
