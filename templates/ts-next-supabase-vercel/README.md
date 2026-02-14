# TypeScript + Next.js + Supabase + Vercel Template

**Stack TS-B (when you need Postgres + RLS + vector in one)**

## Overview
This template provides a full-stack TypeScript application with:
- Next.js App Router (frontend)
- Supabase (Postgres DB + auth + storage + real-time + vector)
- Vercel deployment
- Vitest (unit tests)
- Playwright (E2E tests)
- OpenTelemetry instrumentation stubs

## Structure

```
.
├── app/                    # Next.js App Router
│   ├── layout.tsx
│   └── page.tsx
├── components/             # React components
├── lib/
│   ├── supabase/          # Supabase client + utilities
│   └── observability.ts   # OTel stubs
├── supabase/
│   ├── migrations/        # Database migrations
│   └── seed.sql           # Seed data
├── tests/
│   ├── unit/              # Vitest unit tests
│   └── e2e/               # Playwright E2E tests
├── package.json
├── tsconfig.json
└── vitest.config.ts
```

## Tech Stack
- **Next.js 14+** (App Router, React Server Components)
- **Supabase** (Postgres, auth, storage, real-time, vector search)
- **TypeScript** (strict mode)
- **Tailwind CSS** (styling)
- **Vitest** (unit testing)
- **Playwright** (E2E testing)
- **OpenTelemetry** (observability)

## Development

```bash
npm install
npm run dev          # Start Next.js dev server

# Supabase local development
npx supabase start   # Start local Supabase
npx supabase db reset  # Reset DB with migrations
```

## Testing

```bash
npm test             # Run unit tests (Vitest)
npm run test:e2e     # Run E2E tests (Playwright)
```

## Build

```bash
npm run build        # Production build
npx tsc --noEmit     # Type check
```

## Deployment

```bash
vercel deploy        # Deploy to Vercel

# Supabase production
npx supabase db push  # Push migrations to production
```

## Database Migrations

```bash
npx supabase migration new <name>  # Create new migration
npx supabase db reset              # Apply migrations locally
npx supabase db push               # Push to production
```

## DDD Layout
For backend logic, use:
- `lib/domain/` - Domain entities and value objects
- `lib/application/` - Use cases and services
- `lib/infrastructure/` - Supabase client and repositories

## OTel Instrumentation
Stub configuration in `lib/observability.ts`. Enable by setting `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable.

## Auth
Supabase provides built-in auth. Configure providers in Supabase dashboard.

## Cost Warning
Use sparingly - Supabase can incur costs. Prefer ts-next-convex-vercel for most projects.
