# Agent Contract for this repo (Codex + Claude)

## Hard rules
1) **Subscription-only.** Never add API keys, never depend on `OPENAI_API_KEY` or `ANTHROPIC_API_KEY`.
2) **TypeScript-first.** Default to TS unless SPEC.md explicitly says otherwise.
3) **Evidence-first.** Every feature must ship with:
   - tests (unit or E2E as appropriate)
   - run instructions
   - observable logs/events
4) **DDD for apps/api.** Use `domain/ application/ infrastructure/ interfaces/http/ tests/`.
5) **No silent TODOs.** If something is stubbed, add a runnable placeholder + an issue in docs/roadmap.md.

## Working style
- Make small commits with clear messages.
- Prefer deterministic commands and reproducible local runs.
- Avoid adding novel libraries unless necessary.

## Safety
- Do not read from home directories or unrelated paths.
- Do not attempt to exfiltrate secrets.
- Never prompt for API keys.

