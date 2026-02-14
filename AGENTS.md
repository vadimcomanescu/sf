# AGENTS.md — Always-on agent contract (Codex + Claude)

Non-negotiable:
- SUBSCRIPTIONS ONLY. Never add API keys, never require OPENAI_API_KEY or ANTHROPIC_API_KEY.
- Use TypeScript-first.
- apps/api MUST follow DDD folders:
  domain/ application/ infrastructure/ interfaces/http/ tests/
- Every stage emits structured events for UI.
- No big refactors; minimal patches.

Definition of done for any lane:
- typecheck
- unit tests
- basic docs
- commits with clear message

