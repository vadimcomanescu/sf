Implement the backend API (FastAPI) for the software factory.

Must have:
- Domain-driven-ish structure: domain/ application/ infrastructure/ tests/
- Endpoints:
  - POST /runs (create a run for a product spec)
  - GET /runs/{id} (status)
  - POST /runs/{id}/stop
  - GET /events/stream (SSE stream by run_id)
- Persistence: Postgres (can be docker-compose for now)
- Auth: simple API key for now (env var), but design to support Supabase later.

Also:
- Structured event model (RunCreated, AgentStarted, ToolCall, TestResult, DeployResult, etc.)
- Emit events to DB and SSE.

Run + test the API locally. Commit changes.
