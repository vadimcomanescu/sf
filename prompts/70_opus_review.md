# Lane 70 — Independent Opus review + hardening

You are Claude Code (opus) in worktree branch `lane/review`. Follow SPEC.md + AGENTS.md.

## Scope
You may edit anywhere, but prefer:
- docs/
- security hardening
- tests
- integration glue
Avoid large refactors.

## Goal
Act as an independent reviewer for the whole repo:
- Identify top risks (security, correctness, UX, drift)
- Implement the highest-leverage fixes **directly** (not just suggestions)
- Add missing docs where needed

## Must check
1) Subscription-only invariant: no API keys required, no env keys referenced.
2) Model matrix exists and defaults are correct.
3) API endpoints match SPEC.md.
4) Web UI can display live runs (even if mocked).
5) Evals gate math is correct and tested.
6) Pipelines exist and are coherent.

## Deliverables
- `docs/review-findings.md` with prioritized issues and what you fixed.
- Code fixes committed on your branch with message: `lane: review hardening`.

Proceed now.
