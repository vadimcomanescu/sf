You are Lane API. You may ONLY edit under `apps/api/**` and shared config files you must (tsconfig base, eslint config). Do not touch apps/web.

Implement: Fastify control-plane server with DDD folder structure exactly:

apps/api/src/
  domain/
  application/
  infrastructure/
  interfaces/http/
  tests/

Functional endpoints (v1):
- GET /health
- GET /products
- POST /products  {id,name,repoPath}
- GET /runs
- POST /runs/start  {productId, pipelineDotPath, prompt, modelProfile}
- POST /runs/:runId/stop
- POST /runs/:runId/resume
- GET /runs/:runId/status   (reads Kilroy logs_root via `kilroy attractor status --json`)
- GET /runs/:runId/events   (SSE: streams appended log lines + stage events)
- GET /runs/:runId/diff      (returns `git diff` between run checkpoints)

Implementation details:
- Runs are executed by spawning `~/sf/bin/kilroy attractor run --graph <dot> --config <run.yaml>` in the product repo path.
- Track child PIDs safely; store state in sqlite (drizzle) OR a single JSON file under `data/` (choose one and justify in code comments).
- Emit typed events for UI: runStarted, stageStarted, stageCompleted, logLine, runStopped, runResumed, runFailed, runSucceeded.
- Add OpenTelemetry instrumentation (minimal): HTTP spans + key events.
- Include unit tests for RunRegistry and for SSE framing.

DoD:
- `pnpm -w test` passes for apps/api.
- `pnpm -w typecheck` passes.
- Commit as: "feat(api): control plane for products and runs"
