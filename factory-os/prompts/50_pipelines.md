You are Lane PIPELINES. You may ONLY edit:
- pipelines/**
- templates/**
- .agents/skills/**
- docs in repo root (NOT code)

Implement:
- Default DOT pipeline templates for:
  1) build-new-product (Next.js + default backend choice)
  2) add-feature (given prompt)
  3) fix-bug
  4) deploy (Vercel for frontend; Fly.io optional for backend)

Pipelines must:
- include validate/test/eval stages
- checkpoint after each stage
- produce status.json per stage

Also:
- Add at least 2 custom skills (SKILL.md) to `.agents/skills/`:
  - english-to-dotfile (if not using Kilroy’s built-in)
  - write-holdout-scenarios
  - vercel-deploy-dryrun

DoD:
- Each DOT validates via `~/sf/bin/kilroy attractor validate --graph <file>`.
- Commit as: "feat(pipelines): default graphs and skills"
