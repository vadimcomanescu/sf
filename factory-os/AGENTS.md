# AGENTS.md — Factory OS

This repo is built to be executed by coding agents autonomously. **Follow this order**:
1) Read `SPEC.md`
2) Run `pnpm -w i`
3) Implement only your assigned work package (see `prompts/`).
4) Run verifiers required by your package.
5) Commit with a concise message.

## Non-negotiable constraints
- Primary language: **TypeScript**
- Web: **Next.js** (deploy target: Vercel by default)
- Control-plane: **Node + Fastify** (DDD folders below)
- Orchestration engine: **Kilroy** (Go binary), running StrongDM-style Attractor DOT graphs.
- Always emit **structured run events** suitable for UI streaming.
- Every change must be verifiable via tests + scenario harness. No “it should work”.

## DDD folder layout (apps/api)
apps/api/src/
  domain/
  application/
  infrastructure/
  interfaces/http/
  tests/

If you disagree, you must *prove* a better structure for agent reliability and update SPEC.md accordingly.

## Definition of Done (DoD) for any task
- Typecheck passes
- Unit tests pass
- No broken lint/format
- Any new behavior has tests
- Adds observability events (OTel + local logs)
- Works on mac/linux; no hardcoded absolute paths (use config)

## Agent-ops
- Do not touch holdout scenarios. Holdouts live outside repo and are executed by eval harness.
- Avoid refactors. Minimum change to satisfy spec.
- Prefer small modules with pure functions + typed I/O contracts.
