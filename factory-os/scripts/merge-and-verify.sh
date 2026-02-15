#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Merge lanes in an order that reduces conflicts
LANES=(scaffold api evals pipelines web)

git checkout -B main || git checkout main

for lane in "${LANES[@]}"; do
  branch="lane/$lane"
  if git show-ref --verify --quiet "refs/heads/$branch"; then
    echo "==> Merging $branch"
    git merge --no-ff "$branch" -m "merge: $branch"
  else
    echo "WARN: missing $branch"
  fi
done

echo "==> Install + verify"
pnpm -w i
pnpm -w typecheck
pnpm -w test
pnpm -w build

echo "✅ Merge + verify complete"
