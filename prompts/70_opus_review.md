# LANE 70 — REVIEW/HARDEN (Claude Opus)

Scope: you can change anything, but keep diffs small and high leverage.

Goal: Hardening pass focused on:
- subscription-only invariants (no API keys)
- correctness
- observability events
- testability
- minimal drift

Deliverables:
- docs/review_findings.md (prioritized)
- implement top 3 fixes directly (commit)
- write DONE marker instruction for integrator: create $SF_RUN_DIR/70_review.done at end.

When finished, print: "REVIEW DONE" and ensure your branch commits are ready to merge.
