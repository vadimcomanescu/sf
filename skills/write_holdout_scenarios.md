# write_holdout_scenarios

**Purpose**: Guide LLMs in creating holdout evaluation scenarios for product acceptance testing.

**When to use**: When building a new product or feature and you need to create acceptance scenarios that are NOT visible to the implementing LLMs (holdouts prevent overfitting).

## Core Principle

Holdout scenarios are acceptance tests that remain **outside the repository** and invisible to implementers. This prevents LLMs from optimizing for the test suite ("teaching to the test") and ensures genuine product quality.

## Where Holdouts Live

- **NOT in the product repo** (implementers would see them)
- Store in: `~/.sf/holdouts/<product-name>/scenarios/`
- Factory evaluator reads from this location
- Version control separate from product code

## Holdout Scenario Structure

Each scenario is a YAML file:

```yaml
id: scenario_001
name: "User registration with email verification"
description: "Complete user signup flow with email confirmation"
tags: ["auth", "email", "critical"]
acceptance_criteria:
  - "User can enter email and password"
  - "Validation errors show for invalid email"
  - "Email verification link is sent"
  - "Clicking link activates account"
  - "User can log in after activation"

test_type: "e2e"  # or "unit", "integration", "manual"
automated: true
priority: "critical"  # or "high", "medium", "low"

# For automated scenarios
test_script: |
  // Playwright or similar test code
  await page.goto('/signup')
  await page.fill('#email', 'test@example.com')
  await page.fill('#password', 'secure123')
  await page.click('button[type=submit]')
  await expect(page.locator('.success')).toBeVisible()

  // Check email (mock or test mailbox)
  const verifyLink = await getVerificationLink('test@example.com')
  await page.goto(verifyLink)
  await expect(page.locator('.account-active')).toBeVisible()

expected_outcome: "Account created and verified successfully"
```

## Creating Quality Holdouts

### 1. Derive from Product Brief
Read the product brief and extract:
- Core user flows (signup, checkout, search, etc.)
- Edge cases (empty states, errors, limits)
- Non-functional requirements (performance, accessibility)

### 2. Cover Critical Paths
Focus on scenarios that:
- Represent core business value
- Are likely points of failure
- Cover integration between components
- Test happy path AND error paths

### 3. Include Negative Tests
Don't just test success cases:
```yaml
id: scenario_002
name: "Registration prevents weak passwords"
acceptance_criteria:
  - "Password 'abc' is rejected as too short"
  - "Password '12345678' is rejected as too simple"
  - "Error message guides user to requirements"
```

### 4. Make Them Deterministic
Scenarios must produce consistent results:
- Use fixed test data
- Mock time/dates if needed
- Avoid flaky network dependencies
- Reset state between tests

### 5. Tag by Domain
```yaml
tags: ["auth", "critical", "e2e", "email"]
```
Enables running subsets: "run all critical auth scenarios"

## Holdout Organization

```
~/.sf/holdouts/
├── product-a/
│   ├── scenarios/
│   │   ├── auth/
│   │   │   ├── signup.yaml
│   │   │   ├── login.yaml
│   │   │   └── password_reset.yaml
│   │   ├── payments/
│   │   │   ├── checkout.yaml
│   │   │   └── refund.yaml
│   │   └── core/
│   │       ├── search.yaml
│   │       └── navigation.yaml
│   ├── fixtures/
│   │   ├── test_users.json
│   │   └── sample_data.sql
│   └── config.yaml
└── product-b/
    └── scenarios/
        └── ...
```

## Integration with Factory Pipeline

The `new_product` pipeline has a `run_evals` stage that:

1. Reads holdout scenarios from `~/.sf/holdouts/<product-name>/scenarios/`
2. Executes each scenario against the implementation
3. Records pass/fail for each scenario
4. Computes satisfaction metric: `passed / total`
5. Applies statistical gate (Clopper-Pearson lower bound)
6. Fails the run if satisfaction < threshold (default 0.98)

## Example Workflow

1. Product brief arrives: "Build a task management app"

2. You (as holdout writer) create scenarios:
   ```bash
   mkdir -p ~/.sf/holdouts/taskapp/scenarios/{core,auth,api}
   ```

3. Write critical scenarios:
   - `core/create_task.yaml` (happy path)
   - `core/create_task_validation.yaml` (empty title rejected)
   - `core/mark_complete.yaml` (task state transitions)
   - `core/delete_task.yaml` (confirm deletion)
   - `auth/task_isolation.yaml` (users only see own tasks)

4. Set total scenarios: 20 (5 critical + 15 additional)

5. Factory runs implementation → adjudication → evals

6. Eval stage executes 20 holdout scenarios

7. Results: 19 passed, 1 failed (task isolation bug)

8. Satisfaction: 19/20 = 0.95
   - Clopper-Pearson lower bound (95% confidence): 0.75
   - Below threshold (0.98) → **FAIL**

9. Factory retries or escalates

## Statistical Acceptance

See SPEC.md for Clopper-Pearson details. Key insight:

- **Don't just look at pass rate** (19/20 = 95% sounds good but is it?)
- **Check confidence bound** (we're 95% confident true rate ≥ 75%)
- Small sample sizes have wide confidence intervals
- More scenarios = tighter bounds = more confidence

## Manual Holdouts

Not all scenarios can be automated:

```yaml
id: scenario_099
name: "App is visually appealing and professional"
test_type: "manual"
automated: false
priority: "high"
instructions: |
  1. Open the app
  2. Subjectively assess visual design
  3. Check color contrast (WCAG AA)
  4. Verify consistent spacing and typography
  5. Test on mobile and desktop
acceptance_criteria:
  - "Design feels modern and professional"
  - "No obvious visual bugs"
  - "Accessible color contrast"
  - "Responsive layout works well"
```

Manual scenarios require human judgment during eval stage.

## Anti-Patterns (DON'T)

❌ **Don't commit holdouts to product repo**
```bash
# WRONG - implementers will see these
product-a/tests/acceptance/holdout_scenarios.yaml
```

❌ **Don't make scenarios too granular**
```yaml
# TOO GRANULAR
id: scenario_050
name: "Password field has type=password attribute"
```
This is implementation detail, not acceptance criterion.

❌ **Don't hardcode environment specifics**
```yaml
# WRONG - brittle
test_script: |
  await page.goto('http://localhost:3000/signup')
```
Use config to inject base URL.

❌ **Don't create interdependent scenarios**
```yaml
# WRONG - scenario B depends on scenario A having run
id: scenario_002
name: "Update the task created in scenario_001"
```
Each scenario must be independent.

## Best Practices

✅ **Use BDD-style naming**
```yaml
name: "User can create a task with title and due date"
name: "Duplicate email addresses are rejected during signup"
```

✅ **Cover the acceptance triangle**
- Happy paths (core flows work)
- Edge cases (empty states, limits)
- Error paths (validation, network failures)

✅ **Make scenarios readable**
Non-technical stakeholders should understand what each scenario tests.

✅ **Version holdouts separately**
```bash
~/.sf/holdouts/taskapp/.git/  # Separate repo
```
Track changes to acceptance criteria over time.

✅ **Review scenario coverage**
After writing scenarios, check:
- All critical user flows covered?
- Both success and failure cases?
- Security scenarios included?
- Accessibility scenarios included?

## Common Scenario Types

### Auth Scenarios
- Signup (valid, invalid email, weak password)
- Login (correct, incorrect, account locked)
- Password reset
- Session expiry
- Multi-factor auth

### CRUD Scenarios
- Create (valid, invalid, duplicate)
- Read (exists, not found, unauthorized)
- Update (valid, concurrent edit, unauthorized)
- Delete (exists, already deleted, unauthorized)

### Integration Scenarios
- External API calls (success, timeout, error)
- Payment processing (success, declined, retry)
- Email sending (delivered, bounced)

### Performance Scenarios
```yaml
id: scenario_080
name: "Search returns results within 500ms"
test_type: "performance"
acceptance_criteria:
  - "Search query completes in < 500ms (p95)"
  - "Database query is indexed"
  - "Results are paginated"
```

### Accessibility Scenarios
```yaml
id: scenario_090
name: "Forms are keyboard-navigable"
test_type: "accessibility"
acceptance_criteria:
  - "All form fields reachable via Tab"
  - "Submit button activates on Enter"
  - "Focus indicators visible"
  - "Screen reader announces field labels"
```

## Tool Support

The factory provides helpers:

```bash
# Validate holdout scenario structure
sf holdout validate ~/.sf/holdouts/taskapp/scenarios/

# Run holdouts locally (before pipeline)
sf holdout run taskapp --local

# Generate scenario template
sf holdout new taskapp --name "User can export tasks" --type e2e
```

## Summary

Holdout scenarios are the **ground truth** for product acceptance. Keep them:

1. **Invisible** to implementers (outside repo)
2. **Comprehensive** (happy + edge + error paths)
3. **Deterministic** (consistent results)
4. **Automated** where possible (but include manual for UX/design)
5. **Statistical** (use confidence bounds, not just pass rate)

This prevents LLMs from gaming the tests while ensuring genuine quality.
