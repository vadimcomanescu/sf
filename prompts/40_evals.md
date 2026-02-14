# LANE 40 — EVALS + STAT GATE (Codex Spark xhigh)

Scope: only edit `packages/evals/**` (and types in packages/contracts if needed).

Goal: Implement the evaluation harness for the Validation Constraint.

Deliverables:
1) Scenario format (v1):
   - JSON-based scenario files: {name, command, timeoutSec, expect: {exitCode, contains?}}
   - Runner executes scenarios and returns pass/fail + evidence.
2) Statistical acceptance:
   - Implement Clopper–Pearson lower bound for binomial pass rate.
   - Gate passes if lowerBound(alpha=0.05) >= threshold (default 0.98).
3) Tournament helper:
   - sequential halving: evaluate K candidates on small subset, keep top half, expand budget, repeat.
4) CLI:
   - `pnpm -C packages/evals evals:run --scenarios <dir> --alpha 0.05 --threshold 0.98`
   - writes eval_report.json

Tests:
- unit tests for Clopper–Pearson (known values)
- unit tests for scenario runner

Definition of done:
- `pnpm -C packages/evals test` passes
- Commit: "lane: evals"
