You are Lane EVALS. You may ONLY edit under `packages/evals/**` plus minimal shared config.

Implement: evaluation harness + statistical acceptance gate.

Required modules:
1) Scenario format:
- A scenario is a directory with:
  - scenario.json (name, type, command, timeout, expected)
  - optional fixtures/
- Runner must execute scenarios and return structured results.

2) Stats gate:
- Implement Clopper–Pearson lower bound for binomial pass rate.
- API: accept if lowerBound(alpha=0.05) >= target=0.98.

3) Tournament selection:
- Given K candidates with deterministic screens, run holdouts and pick winner.
- Use sequential halving: evaluate all on small batch, keep top half, increase batch, repeat.

4) Artifacts:
- Write eval_report.json with scenario results, lowerBound, decision, winner.

DoD:
- Unit tests for Clopper–Pearson with known values.
- Example scenarios under packages/evals/examples/ that run on this repo itself.
- Commit as: "feat(evals): scenario harness and acceptance gate"
