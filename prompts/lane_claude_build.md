You are Claude in OPUSPLAN mode (Opus plans, Sonnet executes).

Implement the orchestration/runner core:
- A local “factory” CLI (Node/TS preferred) that can:
  - create run
  - spawn agent lanes (via codex exec / claude -p) OR stub with adapters
  - collect logs/events into the backend DB
  - stream events to WebUI through backend SSE

Design constraints:
- Multiple products concurrently (run isolation)
- Append-only event log per run
- Stop/resume semantics (stop should actually stop running subprocesses)
- Robustness: timeouts, retries, idempotency keys, crash recovery

Commit changes.
