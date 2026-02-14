# TypeScript + Next.js + FastAPI + Fly.io Template

**Stack PY-A (when long-running / scientific / heavy orchestration)**

## Overview
This template provides a full-stack application with:
- Next.js App Router (frontend)
- FastAPI (Python backend with DDD layout)
- Fly.io deployment (backend)
- Vercel deployment (frontend)
- Vitest (frontend unit tests)
- Pytest (backend unit tests)
- Playwright (E2E tests)
- OpenTelemetry instrumentation stubs

## Structure

```
.
├── frontend/
│   ├── app/               # Next.js App Router
│   ├── components/
│   ├── lib/
│   ├── tests/
│   ├── package.json
│   └── tsconfig.json
├── backend/
│   ├── src/
│   │   ├── domain/        # Domain entities and value objects
│   │   ├── application/   # Use cases and services
│   │   ├── infrastructure/  # DB, external services
│   │   ├── interfaces/
│   │   │   └── http/      # FastAPI routes
│   │   └── main.py
│   ├── tests/
│   ├── pyproject.toml
│   └── Dockerfile
├── docker-compose.yml     # Local development
└── fly.toml               # Fly.io deployment config
```

## Tech Stack
- **Frontend**: Next.js 14+ (App Router, React Server Components)
- **Backend**: FastAPI (Python 3.11+)
- **Database**: Postgres (Fly.io managed or separate)
- **TypeScript** (strict mode, frontend)
- **Python** (type hints, backend)
- **Tailwind CSS** (styling)
- **Vitest** (frontend unit testing)
- **Pytest** (backend unit testing)
- **Playwright** (E2E testing)
- **OpenTelemetry** (observability)

## Development

```bash
# Frontend
cd frontend
npm install
npm run dev

# Backend
cd backend
uv sync                 # Install dependencies with uv
uv run uvicorn src.main:app --reload

# Or use docker-compose for full stack
docker-compose up
```

## Testing

```bash
# Frontend tests
cd frontend
npm test                # Vitest unit tests
npm run test:e2e        # Playwright E2E tests

# Backend tests
cd backend
uv run pytest -v
```

## Build

```bash
# Frontend
cd frontend
npm run build
npx tsc --noEmit

# Backend
cd backend
uv run pytest -v        # Ensure tests pass
```

## Deployment

```bash
# Frontend (Vercel)
cd frontend
vercel deploy

# Backend (Fly.io)
cd backend
fly deploy
```

## DDD Layout (Backend)
Required structure for `backend/src/`:
- `domain/` - Pure business logic, entities, value objects
- `application/` - Use cases, application services
- `infrastructure/` - DB repositories, external API clients
- `interfaces/http/` - FastAPI routes and schemas

## OTel Instrumentation
- Frontend: `frontend/lib/observability.ts`
- Backend: `backend/src/infrastructure/observability.py`

Enable by setting `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable.

## Database
Configure Postgres connection in `backend/src/infrastructure/database.py`.

For Fly.io managed Postgres:
```bash
fly postgres create
fly postgres attach <postgres-app-name>
```

## Python Tooling
Uses `uv` and `pyproject.toml` (no pip venvs or requirements.txt).

## When to Use
- Long-running background jobs
- Scientific computing / ML workloads
- Heavy data processing
- Complex orchestration
- Python ecosystem libraries required
