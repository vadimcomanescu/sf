# LANE 30 — WEBUI (Codex Spark xhigh)

Scope: only edit `apps/web/**` and shared types if needed.

Goal: Next.js WebUI that shows runs in real time.

Pages:
- / (products list + create product)
- /products/[id] (product detail + start run form)
- /runs/[runId] (live run console)

Live run console must show:
- status badge (running/stopped/succeeded/failed)
- timeline view of stages (can be stubbed from events)
- log stream (SSE)
- stop/resume buttons
- links to run artifacts folder path (runs/<runId>/...)

Constraints:
- Use EventSource SSE from API.
- Keep UI minimal but functional.

Tests:
- One Playwright smoke test: UI loads / and lists products (mock if needed)

Definition of done:
- `pnpm -C apps/web build` passes
- `pnpm -C apps/web test` passes (unit + e2e if configured)
- Commit: "lane: webui"
