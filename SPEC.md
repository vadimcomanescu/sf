# SF Factory OS — SPEC (Final)

You are building a **local-first autonomous software factory** that can build many products/day.

## Hard Constraints
- Subscription-only: **NO API KEYS**. Codex CLI (ChatGPT auth), Claude Code (subscription auth).
- TypeScript-first.
- Real-time WebUI visibility for everything.
- Multi-product & multi-run concurrency.
- Stop/Resume for every run.
- Self-verifying: deterministic tests + scenario evaluation + statistical acceptance.

## Tech Stack (Factory Itself)
- apps/web: Next.js (App Router) + TypeScript + Tailwind
- apps/api: Fastify + TypeScript, DDD folders:
  - domain/ application/ infrastructure/ interfaces/http/ tests/
- Persistence: SQLite (local-first)
- Event stream: SSE (server-sent events)
- Verification:
  - Typecheck (tsc)
  - Unit tests (Vitest)
  - E2E (Playwright)
  - Scenario harness + satisfaction metric
  - Statistical gate (Clopper–Pearson lower confidence bound)
- Orchestration:
  - Run engine is **DOT pipeline execution** (Attractor-style).
  - For v1, implement a minimal DOT runner in TS OR call an external runner via tool wrapper.
  - Store full evidence per run under runs/<runId>/...

## Model Matrix (Defaults)
- implement_ts_fast: Codex Spark (xhigh)
- implement_ts_deep: Codex (xhigh)
- review: Claude Opus
- plan: Claude OpusPlan (Opus plans → Sonnet executes)
- fallback: Claude Sonnet, Codex 5.2-codex

## Correctness Strategy (Core Novelty)
- Don’t trust “LLM wrote tests therefore tests passing = correct.”
- Maintain **holdout scenarios** not visible to implementers.
- Run tournament parallel candidates.
- Accept only if:
  - deterministic gates pass AND
  - Clopper–Pearson lower bound >= threshold (default 0.98 at alpha=0.05)

