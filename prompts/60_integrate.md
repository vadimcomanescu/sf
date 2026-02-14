# LANE 60 — INTEGRATE (Codex, merge sheriff)

You run on the main branch workspace.

Goal: Merge all lanes and make the repo green.

Wait until these DONE files exist in $SF_RUN_DIR:
- 10_scaffold.done
- 20_api.done
- 30_webui.done
- 40_evals.done
- 50_pipelines.done
- 70_review.done (optional but merge if exists)

Then:
1) Merge lane branches into current branch in this order:
   - lane/scaffold
   - lane/api
   - lane/evals
   - lane/pipelines
   - lane/webui
   - lane/review (if exists)
2) Resolve conflicts minimally.
3) Run:
   - pnpm -w i
   - pnpm -w typecheck
   - pnpm -w test
   - pnpm -w build
4) Fix failures until green.
5) Write runs/<runId>/INTEGRATION_SUMMARY.md explaining how to run locally.
6) Commit: "chore: integrate lanes"

