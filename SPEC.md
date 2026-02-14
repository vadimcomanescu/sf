# SF — Software Factory (local-first, subscription-only)

This repo is the **bootstrap + control plane** for a **software factory** that can:
- build many products in parallel,
- iterate features autonomously,
- verify work without human code review,
- expose everything in a **real-time Web UI**.

It follows the **Validation Constraint**: treat code as opaque and infer correctness from externally observable behavior (scenarios, satisfaction), not from human review. Inspired by StrongDM’s Software Factory techniques (scenarios as holdouts, DTU clones, filesystem as model memory, shift work, etc.).  
(References are in docs/ if needed; no external browsing required at runtime.)

---

## Non‑negotiables

### Subscription-only (no paid API keys)
- Do **not** require or store API keys.
- All LLM actions must run through:
  - **Codex CLI** authenticated via ChatGPT subscription (ChatGPT OAuth)
  - **Claude Code CLI** authenticated via claude.ai subscription
- Fail fast if `OPENAI_API_KEY` or `ANTHROPIC_API_KEY` is set.

### Default language + drift minimization
- **TypeScript-first** everywhere it makes sense.
- Prefer minimal, common, well‑learned libraries and patterns.

### Core tech choices (factory itself)
- **Web UI:** Next.js (App Router), Tailwind, deployable to Vercel
- **Control plane API:** Fastify (TypeScript), **DDD folder layout**
- **Orchestration engine:** **Kilroy** (Go binary) executing **Attractor DOT graphs**
- **State:** SQLite (local-first) for indexing products/runs; run artifacts live in `runs/`
- **Testing:** Vitest (unit), Playwright (E2E, optional visual), TypeScript strict
- **Observability:** OpenTelemetry -> local Grafana stack via docker compose

### Agentic correctness strategy (core novelty)
We do not rely on “tests written by the same model that wrote the code” alone.
We combine:
1. **Holdout scenarios** (not visible to implementer stages) → satisfaction metric
2. **Tournament parallelism** (Codex vs Claude solutions) → select via evidence
3. **Digital Twin Universe (DTU) stubs** for 3rd‑party APIs when needed (replayable)
4. **Statistical gates** (e.g., Clopper–Pearson lower bound for satisfaction) in CI
5. **Event-sourced evidence ledger** (immutable run logs + artifacts) to audit and replay
6. **Self-hosting test:** factory runs a small pipeline against itself or a fixture repo

---

## Model matrix (defaults)

Factory must store a model routing policy in `model-matrix.json`:

- `plan` → Claude `opusplan`
- `implement_ts_fast` → Codex `gpt-5.3-codex-spark` (reasoning xhigh)
- `implement_ts_deep` → Codex `gpt-5.3-codex` (reasoning xhigh)
- `review` → Claude `opus`
- `debug` → Codex `gpt-5.3-codex`
- `fallback` → Claude `sonnet` and Codex `gpt-5.2-codex`

This must be configurable per-run, but defaults should be strong.

---

## Product stacks (templates the factory can generate)

We intentionally restrict to a few “agent-friendly” stacks to reduce drift.

### Stack TS‑A (default, fast product iteration)
- Next.js + TypeScript
- Convex (DB + auth) when appropriate (agent-friendly)
- Vercel deploy

### Stack TS‑B (when you need Postgres + RLS + vector in one)
- Next.js + Supabase + Vercel
- Use sparingly (cost), but supported

### Stack PY‑A (when long-running / scientific / heavy orchestration)
- Next.js frontend + FastAPI backend
- Deploy backend on Fly.io
- Postgres (Fly or managed)

### Systems/IO
- Prefer Go for high‑throughput IO microservices
- Prefer Rust for CPU-bound, memory safety critical components

---

## Folder conventions (factory itself)

### apps/api — DDD layout (required)
apps/api/src/
  domain/
  application/
  infrastructure/
  interfaces/http/
  tests/

### apps/web — Next.js
apps/web/app/...

### packages/*
Shared libs: contracts, evals, observability, etc.

---

## Must-have UX
- Web UI shows **real-time runs**, per product, per pipeline stage
- Users can **stop / resume** runs
- Multiple runs/products concurrently

---

## “Compiler compiles itself” analogue
The factory must include:
- `pipelines/self_check.dot` that runs:
  - typecheck + tests
  - a minimal “build a toy product” pipeline
  - validation gate
and records evidence in `runs/self-check/...`.

