#!/usr/bin/env bash
set -euo pipefail

echo "=== Preflight: subscriptions-only (no API keys) ==="

deny_vars=(
  OPENAI_API_KEY
  OPENAI_KEY
  CODEX_API_KEY
  ANTHROPIC_API_KEY
  ANTHROPIC_KEY
)

for v in "${deny_vars[@]}"; do
  if [[ -n "${!v:-}" ]]; then
    echo "❌ $v is set. Unset it to avoid pay-per-use API billing."
    echo "   Example: unset $v"
    exit 2
  fi
done

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing dependency: $1"; exit 2; }
}

need_cmd git
need_cmd tmux
need_cmd codex
need_cmd claude

# Codex subscription auth check (ChatGPT OAuth)
if ! codex login status >/dev/null 2>&1; then
  echo "❌ Codex CLI is not logged in."
  echo "   Run: codex login"
  exit 2
fi

echo "✅ Preflight OK: subscription-only mode enforced."
