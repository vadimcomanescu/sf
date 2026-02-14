# Lane 10 — Scaffold the SF repo (monorepo + tooling)

You are Codex running inside a git worktree branch `lane/scaffold`.

Your job: create the *foundation* of the Software Factory repo according to **SPEC.md** and **AGENTS.md**.

## Hard constraints
- Subscription-only: do not add API keys, do not add docs that instruct adding them.
- TypeScript-first.
- Do not implement full business logic of API/UI; just scaffold so other lanes can plug in.

## Deliverables
1) Monorepo skeleton:
   - `apps/api` (Fastify TS, DDD folders only + placeholder server)
   - `apps/web` (Next.js placeholder app)
   - `packages/` (create empty packages with build/test stubs):
     - `packages/contracts`
     - `packages/observability`
     - `packages/evals`
     - `packages/voice`
2) Tooling:
   - pnpm workspace + turbo (or pnpm-only if turbo feels unnecessary)
   - strict TypeScript config shared across packages
   - ESLint + Prettier configs
   - Vitest baseline
   - Playwright baseline (can be empty test)
3) Local-first state dirs: `data/`, `runs/`, `.worktrees/` (already exist but ensure documented)
4) Observability dev stack:
   - `docker-compose.observability.yml` with otel-collector + grafana + tempo + loki (minimal working defaults)
   - `docs/observability.md` explaining how to run locally
5) Kilroy integration scaffolding:
   - `tools/kilroy/README.md` and `tools/kilroy/install.sh` that clones/builds a pinned Kilroy revision into `tools/kilroy/bin/kilroy`
   - `tools/kilroy/kilroy` wrapper script that ensures the binary exists and then execs it
   - Create empty directories: `pipelines/` and `run-configs/` (other lanes will populate)

## Definition of Done
- `pnpm -w install` (or equivalent) works after you add `package.json` and workspace config.
- `pnpm -w lint` passes (even if minimal).
- `pnpm -w test` passes (even if only a placeholder test).
- Commit changes on your branch with message: `lane: scaffold repo`

Proceed now: implement the scaffold, run the checks, commit.
