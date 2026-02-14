# Lane 20 — Build the SF Control Plane API (Fastify + DDD)

You are Codex in worktree branch `lane/api`. Follow SPEC.md + AGENTS.md.

## Scope boundary
- Work only under `apps/api/**` (and add minimal shared types under `packages/contracts/**` if needed).
- Do NOT modify UI code.

## Goal
Implement a local-first Control Plane API that can:
- manage Products and Runs
- start/stop/resume orchestrated pipelines via Kilroy CLI
- stream run status/events to clients (SSE)

## Required endpoints (v1)
- `GET /health`
- `GET /api/products`
- `POST /api/products`  (name, path, stackId)
- `GET /api/products/:productId`
- `POST /api/products/:productId/runs` (pipelineId, specText)
- `GET /api/runs/:runId`
- `POST /api/runs/:runId/stop`
- `POST /api/runs/:runId/resume`
- `GET /api/runs/:runId/events`  (Server-Sent Events; status snapshots at least every 1s)

## Implementation details
- Use Fastify + TypeScript.
- Persist indexing state in SQLite: `data/factory.db`.
- Use DDD folder layout:
  - `domain/` entities + value objects
  - `application/` services/use-cases
  - `infrastructure/` SQLite repo + Kilroy process adapter
  - `interfaces/http/` routes/controllers
  - `tests/` unit/integration tests
- Orchestration:
  - Start run by spawning `tools/kilroy/kilroy attractor run ...`
  - Store `runId`, `productId`, `logsRoot`, `status`, timestamps
  - Implement stop/resume by calling `tools/kilroy/kilroy attractor stop|resume --logs-root <logsRoot>`
  - For SSE, poll `tools/kilroy/kilroy attractor status --logs-root <logsRoot> --json` and emit updates.
- Must support multiple concurrent runs.

## Tests
- Add Vitest tests for:
  - product creation
  - run lifecycle stubs (mock the Kilroy adapter)

## Definition of Done
- `pnpm -C apps/api test` passes.
- `pnpm -C apps/api typecheck` passes.
- Commit with message: `lane: api control plane`
