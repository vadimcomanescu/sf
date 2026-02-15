You are Lane SCAFFOLD. You may edit ANY files, but keep changes minimal and focused.

Task: finish monorepo scaffolding so other lanes can work in parallel.

Requirements:
- Use pnpm workspaces + turbo already present.
- Create baseline tooling shared across workspace:
  - TypeScript config (base tsconfig)
  - ESLint + Prettier
  - Vitest for unit tests
- Add workspace scripts: lint, format, typecheck, test.
- Ensure `pnpm -w i` completes.
- Ensure `pnpm -w typecheck` passes (even if projects are placeholders).
- Commit as: "chore: scaffold monorepo tooling"
