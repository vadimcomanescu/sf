# Lane 30 — Build the SF Web UI (Next.js realtime console)

You are Codex in worktree branch `lane/webui`. Follow SPEC.md + AGENTS.md.

## Scope boundary
- Work only under `apps/web/**` (and minimal shared types under `packages/contracts/**` if needed).
- Do NOT modify API code.

## Goal
Create a Web UI that shows:
- list of products
- per product runs
- real-time run status and logs/events via SSE
- buttons to stop/resume runs

## UI requirements
- Next.js App Router
- Tailwind (preferred) with a clean minimal component set
- Pages:
  - `/` dashboard (products + recent runs)
  - `/products/[id]` product detail (runs list + start run form)
  - `/runs/[id]` run detail (SSE stream, stage/status timeline, stop/resume buttons)
- Use `EventSource` for `/api/runs/:runId/events`.

## Definition of Done
- `pnpm -C apps/web dev` runs and loads pages.
- Add at least 1 Playwright E2E smoke test (can be simple).
- Commit with message: `lane: web ui console`
