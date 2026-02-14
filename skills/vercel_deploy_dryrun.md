# vercel_deploy_dryrun

**Purpose**: Simulate and validate Vercel deployment without actually deploying (dry-run mode).

**When to use**: During product validation stages to verify deployment readiness before actual production deploy. Useful in pipelines to catch deployment issues early.

## Overview

Vercel deployment can fail for many reasons:
- Build errors (not caught locally)
- Environment variable mismatches
- Framework detection issues
- Exceeds size limits
- Configuration errors in `vercel.json`

Running a dry-run **before** adjudication prevents selecting an implementation that would fail to deploy.

## Prerequisites

1. **Vercel CLI installed** (globally or via npx)
   ```bash
   npm install -g vercel
   # or use npx vercel
   ```

2. **Authenticated** (subscription-based, not API token)
   ```bash
   vercel login
   # Opens browser for OAuth flow
   ```

3. **Project context**
   - Must be in project directory
   - `package.json` exists
   - Framework detectable (Next.js, Vite, etc.)

## Dry-Run Command

```bash
vercel build --yes
```

This command:
- ✅ Runs the production build locally
- ✅ Validates `vercel.json` configuration
- ✅ Checks build output structure
- ✅ Detects framework and settings
- ✅ Identifies missing env vars (warns)
- ❌ Does NOT deploy to Vercel
- ❌ Does NOT create a deployment URL
- ❌ Does NOT consume deployment quota

## Usage in Pipelines

### In `new_product.dot` (Before Adjudication)

Add a validation step after parallel implementation:

```dot
validate_deployment [
    shape=box,
    timeout="900s",
    prompt="Goal: $goal

Validate deployment readiness (dry-run).

For each implementation branch (Codex and Claude):

1. cd to project directory
2. Run: vercel build --yes
3. Capture output and exit code

Check:
- Build succeeds (exit code 0)
- No framework detection errors
- Build output size within limits
- All required env vars documented

Write results to .ai/deploy_validation.md with:
- Build success/failure per branch
- Build output size
- Framework detected
- Any warnings or errors
- Missing env vars (if any)

Write status.json: outcome=success if both branches build, outcome=fail otherwise."
]
```

Flow:
```
join_impl -> validate_deployment -> adjudicate
```

Only implementations that pass dry-run proceed to adjudication.

## Detailed Steps

### 1. Install Dependencies
```bash
npm install
# or pnpm install, yarn install
```

Vercel build requires node_modules to exist.

### 2. Run Dry-Run Build
```bash
vercel build --yes
```

The `--yes` flag skips interactive prompts (answers "yes" to all).

### 3. Check Build Output
```bash
echo $?  # Exit code (0 = success, non-zero = failure)
```

Successful output looks like:
```
Vercel CLI 34.0.0
> Detected Next.js
> Building...
> Success! Build completed in 45s
Build Completed in .vercel/output [1.2 MB]
```

Failed output might show:
```
Error: Build failed
> Module not found: Can't resolve 'some-package'
```

### 4. Inspect Build Artifacts
```bash
ls -lh .vercel/output
```

Vercel creates `.vercel/output/` with:
- `static/` - Static assets
- `functions/` - Serverless functions
- `config.json` - Output configuration

Check total size:
```bash
du -sh .vercel/output
```

Vercel limits:
- **Free**: 100 MB per deployment
- **Pro/Team**: 500 MB per deployment

### 5. Validate Configuration

If `vercel.json` exists, verify structure:
```json
{
  "buildCommand": "npm run build",
  "outputDirectory": ".next",
  "framework": "nextjs",
  "env": {
    "NEXT_PUBLIC_API_URL": "@api_url"
  }
}
```

Common issues:
- Wrong `outputDirectory` (should be `.next` for Next.js)
- Framework detection overridden incorrectly
- Missing environment variable references

### 6. Check Environment Variables

Vercel warns if env vars are referenced but not set:
```
Warning: Environment variable "DATABASE_URL" is not set
```

During dry-run, this is a **warning** not an error. But note it for actual deployment.

## Output Validation

What to check in `.ai/deploy_validation.md`:

```markdown
# Deployment Validation (Dry-Run)

## Codex Branch

**Build Status**: ✅ Success
**Framework Detected**: Next.js 14.1.0
**Build Time**: 42s
**Output Size**: 1.1 MB
**Exit Code**: 0

**Warnings**:
- Environment variable "DATABASE_URL" not set (expected, will be set in Vercel)

**Build Artifacts**:
- .vercel/output/static/ (800 KB)
- .vercel/output/functions/ (300 KB)
- .vercel/output/config.json

---

## Claude Branch

**Build Status**: ❌ Failed
**Framework Detected**: Next.js 14.1.0
**Build Time**: N/A
**Exit Code**: 1

**Error**:
```
Module not found: Can't resolve '@/components/Hero'
  at /home/user/project/app/page.tsx:3:0
```

**Analysis**:
Import path error - component file missing or incorrect alias.

---

## Recommendation

**Select**: Codex branch
**Reason**: Claude branch has unresolved import error preventing build.
```

## Environment Variable Handling

During dry-run, you won't have production env vars set. Handle this:

### Option A: Use `.env.local` (Recommended)
```bash
# Create temporary .env.local with dummy values
cat > .env.local <<EOF
DATABASE_URL=postgresql://localhost:5432/testdb
NEXT_PUBLIC_API_URL=https://api.example.com
EOF

# Run dry-run
vercel build --yes

# Clean up
rm .env.local
```

### Option B: Document Missing Vars
If you can't provide dummy values, document them:
```markdown
**Missing Environment Variables** (will be set in Vercel):
- DATABASE_URL (Postgres connection string)
- STRIPE_SECRET_KEY (Stripe API key)
```

Ensure these are configured in Vercel project settings before actual deploy.

## Framework-Specific Notes

### Next.js
```bash
vercel build --yes
```
Detects automatically. Checks:
- `next.config.js` or `next.config.mjs` valid
- `app/` or `pages/` directory exists
- Output directory is `.next`

### Vite/React
```bash
vercel build --yes
```
Checks:
- `vite.config.ts` valid
- Build script in `package.json`
- Output directory (usually `dist`)

### SvelteKit
```bash
vercel build --yes
```
Checks:
- `svelte.config.js` valid
- Adapter configured (`@sveltejs/adapter-vercel`)

## Common Errors

### 1. Module Not Found
```
Error: Module not found: Can't resolve '@/lib/utils'
```

**Fix**: Check import paths, ensure file exists, verify `tsconfig.json` paths.

### 2. Framework Not Detected
```
Error: No framework detected
```

**Fix**: Add `framework` to `vercel.json` or ensure recognizable project structure.

### 3. Build Script Missing
```
Error: Missing required "build" script in package.json
```

**Fix**: Add build script:
```json
{
  "scripts": {
    "build": "next build"
  }
}
```

### 4. Output Directory Wrong
```
Error: Output directory "dist" not found
```

**Fix**: Check `vercel.json` `outputDirectory` matches actual build output.

### 5. Build Timeout
```
Error: Build exceeded maximum duration
```

**Fix**: Optimize build (reduce dependencies, use caching). Vercel limits:
- Free: 45 minutes
- Pro: 90 minutes

## Integration Example

```typescript
// scripts/verify-deployment.ts
import { execSync } from 'child_process'
import fs from 'fs'

interface ValidationResult {
  success: boolean
  framework: string | null
  buildTime: number
  outputSize: number
  errors: string[]
  warnings: string[]
}

async function validateDeployment(): Promise<ValidationResult> {
  const result: ValidationResult = {
    success: false,
    framework: null,
    buildTime: 0,
    outputSize: 0,
    errors: [],
    warnings: []
  }

  try {
    const startTime = Date.now()

    // Run dry-run build
    const output = execSync('vercel build --yes', {
      encoding: 'utf-8',
      stdio: 'pipe'
    })

    result.buildTime = Date.now() - startTime
    result.success = true

    // Parse framework from output
    const frameworkMatch = output.match(/Detected (.+)/)
    if (frameworkMatch) {
      result.framework = frameworkMatch[1]
    }

    // Check output size
    if (fs.existsSync('.vercel/output')) {
      const sizeOutput = execSync('du -sb .vercel/output', { encoding: 'utf-8' })
      result.outputSize = parseInt(sizeOutput.split('\t')[0])
    }

    // Extract warnings
    const warningLines = output.split('\n').filter(line => line.includes('Warning:'))
    result.warnings = warningLines

  } catch (error: any) {
    result.success = false
    result.errors.push(error.message)
    if (error.stderr) {
      result.errors.push(error.stderr.toString())
    }
  }

  return result
}

// Run validation
validateDeployment().then(result => {
  console.log(JSON.stringify(result, null, 2))
  process.exit(result.success ? 0 : 1)
})
```

Usage:
```bash
npm exec tsx scripts/verify-deployment.ts
```

## Cleanup

After dry-run:
```bash
rm -rf .vercel/output
```

The `.vercel/output` directory can be large. Clean it up before committing.

## Actual Deployment (After Dry-Run Passes)

Once dry-run succeeds and implementation is selected:

```bash
# Preview deployment (non-production)
vercel --yes

# Production deployment
vercel --prod --yes
```

But during pipeline validation, **ONLY** run dry-run, never actual deploy.

## Best Practices

1. **Run dry-run on ALL candidate implementations**
   - Before adjudication
   - Eliminates non-deployable branches early

2. **Check build output size**
   - Warn if approaching limits
   - Large builds are slower to deploy

3. **Document env vars**
   - List all required env vars in `.ai/deploy_validation.md`
   - Ensure they're set in Vercel before prod deploy

4. **Test with production settings**
   - Use `NODE_ENV=production` during dry-run
   - Catch issues that only appear in prod build

5. **Validate on same Node version**
   - Match Vercel's Node version (check Vercel dashboard)
   - Avoid "works locally, fails on Vercel"

## Summary

`vercel_deploy_dryrun` prevents deployment surprises by:

- ✅ Validating builds **before** deployment
- ✅ Catching config errors early
- ✅ Ensuring framework detection works
- ✅ Checking output size limits
- ✅ Identifying missing env vars

Use it as a gate in pipelines to ensure only deployable implementations proceed.
