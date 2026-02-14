# TypeScript + Next.js + Convex + Vercel Template

**Stack TS-A (default, fast product iteration)**

## Overview
This is the default template for SF factory products. It provides a full-stack TypeScript application with:
- Next.js App Router (frontend)
- Convex (DB + real-time + auth)
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
├── convex/                 # Convex backend functions
│   ├── _generated/
│   └── schema.ts
├── lib/                    # Shared utilities
├── public/                 # Static assets
├── tests/
│   ├── unit/              # Vitest unit tests
│   └── e2e/               # Playwright E2E tests
├── convex.json
├── next.config.js
├── package.json
├── tsconfig.json
└── vitest.config.ts
```

## Tech Stack
- **Next.js 14+** (App Router, React Server Components)
- **Convex** (database, auth, real-time subscriptions)
- **TypeScript** (strict mode)
- **Tailwind CSS** (styling)
- **Vitest** (unit testing)
- **Playwright** (E2E testing)
- **OpenTelemetry** (observability)

## Development

```bash
npm install
npm run dev          # Start Next.js dev server
npx convex dev       # Start Convex dev server (in separate terminal)
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
```

Convex deployment is automatic when linked to your Convex project.

## DDD Layout
Not applicable for this template (frontend-focused). If you need backend logic, use Convex functions in `convex/` directory.

## OTel Instrumentation
Stub configuration in `lib/observability.ts`. Enable by setting `OTEL_EXPORTER_OTLP_ENDPOINT` environment variable.

## Auth
Convex provides built-in auth. Configure providers in `convex/auth.config.ts`.
