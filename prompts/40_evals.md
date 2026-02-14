# Lane 40 — Implement evals + statistical gates (satisfaction)

You are Codex in worktree branch `lane/evals`. Follow SPEC.md + AGENTS.md.

## Scope boundary
- Work only under `packages/evals/**` (+ optional `packages/contracts/**` for types).
- Do NOT modify API/UI.

## Goal
Create an evaluation harness that supports the Validation Constraint:
- Scenarios can be executed and scored (satisfaction in [0,1])
- Provide statistical gate based on binomial satisfaction (Clopper–Pearson lower bound)

## Deliverables
- `packages/evals` library + CLI:
  - `pnpm -C packages/evals evals:run --scenario-set <path> --reps 200 --parallel 16`
  - outputs JSON summary + writes evidence artifacts under `runs/<id>/evals/...` if `SF_RUN_DIR` is set
- Scenario format:
  - Keep it simple: YAML or JSON describing steps and “success criteria”
  - For v1, implement a runner that can run “http + playwright” scenarios or stub runner with pluggable adapters.
- Statistical gate:
  - Given N trials and K satisfied, compute conservative lower bound at alpha (default 0.05)
  - Gate passes if lower bound >= threshold (configurable)

## Tests
- Unit tests for bound computation and CLI parsing.

## Definition of Done
- `pnpm -C packages/evals test` passes.
- Commit with message: `lane: evals + gates`
