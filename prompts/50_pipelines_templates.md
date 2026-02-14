# LANE 50 — PIPELINES + TEMPLATES (Claude OpusPlan → Sonnet executes)

Scope: pipelines/** templates/** skills/** (avoid touching apps/api and apps/web).

Goal: Create default pipelines + templates that reduce drift and scale product output.

Deliverables:
1) model-matrix.json exists (root) per SPEC.
2) pipelines (DOT-like or JSON DAG) and a minimal runner contract:
   - pipelines/self_check.dot
   - pipelines/new_product.dot
   - pipelines/add_feature.dot
   - pipelines/fix_bug.dot
   Each pipeline emits stage events + artifacts under runs/<runId>/...
3) templates:
   - templates/ts-next-convex-vercel (default)
   - templates/ts-next-supabase-vercel
   - templates/ts-next-fastify-fly (optional skeleton)
4) skills:
   - skills/write_holdout_scenarios (explains holdouts outside repo)
   - skills/vercel_deploy_dryrun
   - skills/factory_observability

Definition of done:
- Each pipeline has docs and can be validated (even if runner is stubbed).
- Commit: "lane: pipelines"
