# LANE 10 — SCAFFOLD (Codex Spark xhigh)

Goal: Create the baseline **TypeScript monorepo** skeleton for the Factory OS that other lanes build on, with minimal conflicts.

Hard constraints:
- Subscription-only. Never require API keys.
- TypeScript-first.
- Keep root config changes here; other lanes should not touch root configs unless absolutely needed.

Deliverables:
1) Monorepo setup:
   - pnpm workspace
   - turbo (optional but preferred)
   - root scripts: dev/build/test/typecheck/lint
2) apps:
   - apps/api: Fastify TS placeholder server with DDD folder layout (empty modules ok)
   - apps/web: Next.js placeholder that builds
3) packages:
   - packages/contracts: Zod schemas for Event/Run/Product (can be minimal)
   - packages/evals: placeholder package for scenario gate (lane 40 will implement)
4) Observability baseline:
   - create `packages/observability` with OpenTelemetry init stub (no external services required)
5) Developer UX:
   - README.md quickstart that says: pnpm i; pnpm dev
   - .gitignore includes runs/, data/, .worktrees/

Definition of done:
- `pnpm -w i` succeeds
- `pnpm -w typecheck` succeeds
- `pnpm -w build` succeeds
- Commit: "lane: scaffold"
