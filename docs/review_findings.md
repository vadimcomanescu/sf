# Review Findings (Lane 70 Hardening Pass)

Date: 2026-02-14
Reviewer: Claude Opus (lane/review)
Scope: Full codebase audit, subscription-only invariants, correctness, observability, testability

## Priority 1 (Critical) -- Implemented in this branch

### F1: `agent.claude.sh` does not unset OpenAI keys

**File:** `scripts/agent.claude.sh`
**Risk:** The Claude runner only unsets `ANTHROPIC_API_KEY` and `ANTHROPIC_KEY`, but does not unset `OPENAI_API_KEY`, `OPENAI_KEY`, or `CODEX_API_KEY`. While Claude Code itself does not use OpenAI keys, this script is part of a subscription-only system where the invariant is "no API keys present in any agent's env." If a Claude agent spawns a subprocess (e.g., calling `codex exec` from within a pipeline stage), leftover OpenAI keys could route through pay-per-use billing.

**Fix:** Unset all deny-list keys in both `agent.claude.sh` and `agent.claude.sub.sh`, matching the same deny list used by `preflight.sh`.

### F2: `agent.codex.sh` does not unset Anthropic keys

**File:** `scripts/agent.codex.sh`
**Risk:** Mirror of F1. The Codex runner only unsets `OPENAI_API_KEY`, `OPENAI_KEY`, `CODEX_API_KEY` but leaves `ANTHROPIC_API_KEY` and `ANTHROPIC_KEY` in the environment. Same cross-pollination risk if an agent subprocess invokes a Claude tool.

**Fix:** Unset the full deny list in both `agent.codex.sh` and `agent.codex.sub.sh`.

### F3: `meta.env` records `git_rev=HEAD` (literal string) instead of actual SHA

**File:** `scripts/swarm.tmux.sh`
**Risk:** The evidence ledger is the core audit mechanism. Recording `HEAD` as the git revision is useless for forensics. After merges and branch changes, `HEAD` is ambiguous. Every run should record the resolved SHA.

**Fix:** Resolve `HEAD` to the actual commit SHA in `swarm.tmux.sh` before writing `meta.env`.

## Priority 2 (High) -- Recommended for next iteration

### F4: Preflight does not verify Claude subscription status

**Files:** `scripts/preflight.sh`, `scripts/preflight.subscriptions_only.sh`
**Risk:** Both preflight scripts check `codex login status` but have no equivalent check for Claude subscription. If Claude Code is not authenticated, the review lane and pipelines lane will fail at runtime with an opaque error.

**Recommendation:** Add `claude --version` or a lightweight probe to verify Claude CLI is authenticated. Claude Code does not currently expose a `login status` subcommand, so a `claude -p "echo ok" --model sonnet --output-format text` probe (with short timeout) may be the pragmatic check.

### F5: `swarm.tmux.sh` sends commands via `bash -lc` with single-quoted heredoc

**File:** `scripts/swarm.tmux.sh:64`
**Risk:** The `send` function wraps the entire command in single quotes: `bash -lc '$cmd'`. If `$cmd` itself contains single quotes (e.g., from paths with apostrophes or from model names with special characters), the command will break silently. This is fragile.

**Recommendation:** Use `tmux send-keys` with a heredoc approach or escape single quotes in `$cmd`. Alternatively, write each lane's command to a temp script and execute that.

### F6: No timeout or watchdog on individual lane execution

**Files:** `scripts/swarm.tmux.sh`
**Risk:** Each lane runs with no external timeout. If an agent hangs (e.g., model API timeout, infinite loop), the entire swarm stalls indefinitely. The `default_timeout: 1200` in `run-configs/default.yaml` is configuration data, not enforced by the scripts.

**Recommendation:** Wrap each lane command in `timeout <seconds>` or implement a watchdog loop in the swarm script that checks `.done` files and kills stalled lanes.

### F7: Duplicate scripts with unclear precedence

**Files:** `scripts/agent.claude.sh` vs `scripts/agent.claude.sub.sh`, `scripts/agent.codex.sh` vs `scripts/agent.codex.sub.sh`
**Risk:** Two versions of each runner exist (original and `.sub.` variant). They differ in:
- Argument parsing style
- Prompt delivery method (arg vs stdin)
- Codex approval policy (`never` vs `on-request`)
- Fallback chain handling
`swarm.tmux.sh` uses the original (non-sub) variants. If someone uses the wrong variant, behavior diverges silently.

**Recommendation:** Consolidate to one runner per backend. The `.sub.` variants are strictly better (cleaner arg parsing, stdin prompt delivery, proper fallback chain). Delete the originals or add a deprecation notice.

### F8: `bootstrap_sf.sh` hardcodes `anthropic: backend: api` in `run.yaml`

**File:** `bootstrap_sf.sh:213`
**Risk:** The Kilroy `run.yaml` template sets `anthropic: backend: api`, which implies API-key auth. This contradicts the subscription-only invariant. If Kilroy uses this config to route Anthropic calls, it will attempt API-key auth and fail (or worse, succeed if an env key is present).

**Recommendation:** Change to `backend: cli` to match the subscription-only contract, or add a comment explaining that Kilroy handles this differently.

## Priority 3 (Medium) -- Observability and testability gaps

### F9: No structured event schema definition

**Files:** SPEC.md, AGENTS.md, `prompts/20_api.md`
**Risk:** Event types are listed in prompts (runStarted, stageCompleted, etc.) but there is no shared schema (Zod, JSON Schema, or TypeScript types) in the repo. Each lane will independently invent event shapes, leading to drift between API, WebUI, and eval harness.

**Recommendation:** Define event schemas in `packages/contracts/` (as specified in lane 10's prompt) early, even as stubs. The lane 10 prompt mentions `packages/contracts` with Zod schemas but does not provide a concrete schema.

### F10: `model-matrix.json` has no schema validation

**File:** `model-matrix.json`
**Risk:** This is a critical config file (routes every LLM call) with no validation. A typo in a model name or missing field causes silent misconfiguration.

**Recommendation:** Add a Zod schema for model-matrix.json and validate it in preflight.

### F11: `run-configs/default.yaml` Clopper-Pearson threshold mismatch

**Files:** `run-configs/default.yaml:77`, `SPEC.md:43`
**Risk:** SPEC.md states the default threshold is 0.98, but `default.yaml` sets `satisfaction_threshold: 0.90`. This 8% gap means the config is more lenient than the spec. The confidence level is also 0.95 in the config vs alpha=0.05 in the spec (these are equivalent, which is correct).

**Recommendation:** Align `satisfaction_threshold` with SPEC or document the intentional deviation.

### F12: No `.done` marker for non-zero exit codes

**File:** `scripts/swarm.tmux.sh`
**Risk:** `.done` files are only written on success (`&& echo DONE > ...`). If a lane fails, no marker is written, and the integrator waits forever. There is no `.fail` marker or timeout-based detection.

**Recommendation:** Write a `.fail` marker on non-zero exit, e.g.: `|| echo FAIL > "$RUN_DIR/XX_lane.fail"`. Update integrator prompt to check for both `.done` and `.fail`.

### F13: `bootstrap_sf.sh` creates a second AGENTS.md/SPEC.md divergent from root

**File:** `bootstrap_sf.sh`
**Risk:** The bootstrap script writes its own AGENTS.md and SPEC.md into `factory-os/`, which differ from the root-level versions. Two sources of truth for the same contract.

**Recommendation:** Either symlink to root or generate from a single template. The bootstrap versions are more detailed; consider them canonical and sync the root files.

## Priority 4 (Low) -- Polish

### F14: Template dependency versions will drift

**Files:** `templates/*/package.json`
**Risk:** Pinned versions (e.g., `next: ^14.2.0`) will be stale when products are scaffolded months later. No `npm outdated` or renovation mechanism.

**Recommendation:** Add a self_check pipeline stage or cron job that validates template deps against latest stable.

### F15: `install_factory_pack.sh` uses `git add -A` at the end

**File:** `scripts/install_factory_pack.sh:591`
**Risk:** `git add -A` stages everything including potential secrets or unintended files in the working directory. The .gitignore mitigates this, but it's still a risky pattern in a repo designed to be run with unknown directory contents.

**Recommendation:** Use explicit `git add` for known files only.
