You are building the foundation of a “software factory” monorepo.

Goals (in order):
1) Create a monorepo skeleton (pnpm + TypeScript) with:
   - apps/web (Next.js)
   - apps/api (FastAPI in python, uv/poetry/uvicorn)
   - apps/worker (Node/TS runner for orchestration) OR explain why worker should be Python.
   - packages/shared (zod schemas + shared types)
2) Add CI tasks locally runnable: lint, typecheck, unit tests, e2e placeholder.
3) Add repo docs: AGENTS.md (rules), SPEC.md (system overview), and a minimal CONTRIBUTING.md.
4) Make sure installs and basic commands work.

Hard rules:
- Keep changes scoped to your worktree.
- Prefer deterministic tooling + lockfiles.
- Write down “how to run everything locally” in README.
- Commit your changes with clear messages.
