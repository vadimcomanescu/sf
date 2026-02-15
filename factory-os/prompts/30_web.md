You are Lane WEB. You may ONLY edit under `apps/web/**`.

Implement: Next.js WebUI for Factory OS with real-time visibility.

Pages:
- /products (list + create)
- /products/[id] (product detail + start run form)
- /runs/[runId] (live run view)

Live run view must show:
- status badge
- event timeline (SSE)
- log stream (SSE)
- diff viewer (calls /runs/:runId/diff)
- buttons: Stop / Resume

Constraints:
- Use EventSource (SSE) first; fallback to polling if SSE unavailable.
- Keep UI simple but functional; focus on observability.
- Add Playwright smoke test: start dev servers (assume api at localhost:4000) and verify /products loads.

DoD:
- `pnpm -w build` passes for apps/web.
- `pnpm -w test` passes (unit + playwright smoke).
- Commit as: "feat(web): real-time factory console"
