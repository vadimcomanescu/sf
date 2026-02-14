# Lane 50 — Pipelines + Templates + Skills (StrongDM-style, Kilroy/Attractor)

You are Claude Code (opusplan) in worktree branch `lane/pipelines`. Follow SPEC.md + AGENTS.md.

## Scope boundary
Work under:
- `pipelines/**`
- `run-configs/**`
- `templates/**`
- `skills/**`
- `tools/kilroy/**` (only if needed)

Do NOT modify apps/api or apps/web.

## Goal
Make the factory actually able to run:
- a "new product" pipeline
- a "feature iteration" pipeline
- a "self-check" pipeline (factory tests itself)

### Pipelines (DOT graphs)
Create:
- `pipelines/new_product.dot`
- `pipelines/add_feature.dot`
- `pipelines/self_check.dot`

Design them to support multi-model tournament:
- parallel implementers (Codex vs Claude)
- adjudicator/select stage
- run tests
- run eval scenarios
- record evidence

### Run configs
Create `run-configs/default.yaml` suitable for **CLI backends** (no API keys):
- openai provider uses Codex CLI
- anthropic provider uses Claude Code CLI
- set defaults to match SPEC.md model-matrix

### Templates
Create minimal-but-real templates:
- `templates/ts-next-convex-vercel/` (default)
- `templates/ts-next-supabase-vercel/` (supported)
- `templates/ts-next-fastapi-fly/` (optional but include scaffolding)

Templates must include:
- tests (Vitest / Playwright or Pytest)
- OTel instrumentation stub
- basic DDD layout for any backend code

### Skills
Create skills folders (Codex-compatible) under `skills/` with SKILL.md manifests:
- `skills/sf-run-pipeline/`
- `skills/sf-add-feature/`
- `skills/sf-evals-gate/`
- `skills/sf-observability/`

## Definition of Done
- DOT graphs exist and are readable.
- Default run-config exists and references CLI backends.
- Templates are present with README per template.
- Commit with message: `lane: pipelines + templates`
