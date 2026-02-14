#!/usr/bin/env bash
set -euo pipefail

echo "=== Preflight (subscriptions only) ==="

deny=(OPENAI_API_KEY OPENAI_KEY CODEX_API_KEY ANTHROPIC_API_KEY ANTHROPIC_KEY)
for v in "${deny[@]}"; do
  if [[ -n "${!v:-}" ]]; then
    echo "❌ $v is set. Unset it (subscription-only)."
    exit 2
  fi
done

need(){ command -v "$1" >/dev/null 2>&1 || { echo "❌ Missing: $1"; exit 2; }; }
need git
need tmux
need codex
need claude
need bash

# Codex must be logged in (subscription auth)
if ! codex login status >/dev/null 2>&1; then
  echo "❌ Codex not logged in. Run: codex login"
  exit 2
fi

# Optional: warn about broken skills symlinks (your log shows this)
if [[ -d "$HOME/.agents/skills" ]]; then
  broken="$(find "$HOME/.agents/skills" -xtype l 2>/dev/null | head -n 1 || true)"
  if [[ -n "${broken:-}" ]]; then
    echo "⚠️  Broken skills symlink detected under ~/.agents/skills"
    echo "    Example: $broken"
    echo "    Fix: find ~/.agents/skills -xtype l -delete"
  fi
fi

echo "✅ Preflight OK."
