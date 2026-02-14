# LANE 20 — API CONTROL PLANE (Codex Spark xhigh)

Scope: only edit `apps/api/**` and (if required) `packages/contracts/**`.

Goal: Implement the Factory control plane API in **Fastify + TypeScript** with DDD layout.

Required DDD layout:
apps/api/src/
  domain/
  application/
  infrastructure/
  interfaces/http/
  tests/

Features:
1) Products registry (local-first):
   - store in SQLite at `data/factory.db`
   - endpoints:
     - GET /api/products
     - POST /api/products  {name, repoPath, stackId}
2) Runs:
   - POST /api/products/:id/runs  {pipelineId, specText}
   - GET  /api/runs/:runId
   - POST /api/runs/:runId/stop
   - POST /api/runs/:runId/resume
3) SSE live events:
   - GET /api/runs/:runId/events  (SSE)
   - Emit structured events at least once/sec:
     - runStatus snapshot
     - new log lines from run directory (tail)
4) Process orchestration (v1):
   - For now, run pipelines by spawning a local CLI command that writes into runs/<runId>/...
   - Provide an abstraction in infrastructure: `RunExecutor`.
   - Must support stop/resume via PID tracking and signals.

Tests:
- At least unit tests for:
  - Run state transitions
  - SSE framing (basic)

Definition of done:
- `pnpm -C apps/api test` passes
- `pnpm -C apps/api typecheck` passes
- Commit: "lane: api"
