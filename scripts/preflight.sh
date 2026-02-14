#!/usr/bin/env bash
set -euo pipefail

echo "=== Preflight (subscriptions only) ==="

# Fail closed if any API keys are set
deny=(OPENAI_API_KEY OPENAI_KEY CODEX_API_KEY ANTHROPIC_API_KEY ANTHROPIC_KEY)
for v in "${deny[@]}"; do
  if [[ -n "${!v:-}" ]]; then
    echo "❌ $v is set. Unset it to avoid API billing."
    exit 2
  fi
done

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing: $1"; exit 2; }; }
need git
need tmux
need codex
need claude
need bash

# Must be logged into Codex subscription
if ! codex login status >/dev/null 2>&1; then
  echo "❌ Codex is not logged in. Run: codex login"
  exit 2
fi

echo "✅ Preflight OK."
