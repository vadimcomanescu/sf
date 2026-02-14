# Lane 60 — Integrate lanes (merge sheriff)

You are Codex running on the main worktree (repo root). Your job is to merge all lane branches and make the repo runnable.

## Inputs
Lane branches:
- lane/scaffold
- lane/api
- lane/webui
- lane/evals
- lane/pipelines
- lane/review (may contain fixes)

Run markers are written under `$SF_RUN_DIR` (env var), e.g. `20_api.done`.

## Procedure
1) Wait until done markers exist:
   - 10_scaffold.done, 20_api.done, 30_webui.done, 40_evals.done, 50_pipelines.done
2) Merge each lane branch into main (use merge commits).
3) Resolve conflicts favoring SPEC.md + AGENTS.md correctness.
4) Run the repo verification:
   - `pnpm -w install` (or `corepack enable && pnpm -w install`)
   - `pnpm -w lint`
   - `pnpm -w test`
   - If Playwright exists: `pnpm -w e2e` (or best available)
5) Ensure bootstrap scripts work:
   - `./scripts/preflight.subscriptions_only.sh`
   - `./scripts/swarm.tmux.sh` (should no longer fail due to missing prompts)
6) Write/Update:
   - `README.md` quickstart (how to run API + WebUI locally, and how to run a pipeline)
   - `model-matrix.json` per SPEC.md (if not created by others)
7) Commit final integration on main: `chore: integrate factory lanes`

No optional steps. Do it end-to-end.
