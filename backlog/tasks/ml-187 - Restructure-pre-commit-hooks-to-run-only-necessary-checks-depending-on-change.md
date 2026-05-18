---
id: ML-187
title: Restructure pre-commit hooks to run only necessary checks depending on change
status: To Do
assignee: []
created_date: "2026-05-15 08:41"
updated_date: "2026-05-18 14:54"
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Currently pre-commit hooks run the entire verification suite irrespectively of the change. This is inefficient and tedious. Some examples of annoyances.

1. Changes to /backlog items only need the pretty linter.
2. Changes to documentation only need the pretty linter.
3. Changes to the presto application only need to run the (upcoming) presto test suite.
4. Possibly some other patterns, need to verify the complete repo structure.
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Objective

Restructure `scripts/dev/precommit` (the pre-commit hook driver) to inspect staged files and run only the checks relevant to the change, instead of always running the full verification suite (credo, sobelow, tests, shellcheck, prettier, etc.).

### Problem→Solution Mapping

- **Problem**: Staging a markdown file in `docs/` or `backlog/` triggers `mix test` (~minutes), `mix credo`, `shellcheck`, and all other checks — none relevant to markdown.
- **Problem**: Staging `presto/main.py` triggers the full Elixir test suite, but only the presto test suite (`pytest`) is relevant.
- **Problem**: Staging `Dockerfile` doesn't trigger `dev:validate-docker-image` — that check runs only in CI, too late.
- **Solution**: Categorize staged files by path pattern and gate each check behind `grep -qE` on the staged file list. No new dependencies.

## Approach: Pattern-based conditional execution in the precommit script

**Chosen approach**: Modify `scripts/dev/precommit` to read staged file paths (already exported as `$STAGED` by `.git/hooks/pre-commit`) and use `grep -qE` pattern matching to determine which check categories to run.

**Alternatives considered and rejected**:

- **Lefthook / pre-commit framework**: Adds a Node.js dependency, requires config file. Overkill. The project already has a working bash-based pre-commit script; we're just adding conditions.
- **Separate mise tasks per category**: Would require chaining multiple mise invocations, adds indirection without benefit. The single script approach keeps debugging simple (`bash -x scripts/dev/precommit`).
- **Makefile-based**: Unnecessary abstraction layer. Bash with `set -e` is sufficient.
- **Git hook as dispatcher to multiple scripts**: The hook already delegates to `mise run dev:precommit`; keeping all logic in one script is simpler than splitting across hook + multiple scripts.

## File Categories and Their Checks

| Category    | `grep -E` pattern                                                                                                                    | Checks to run                                                                                                                                                                      |
| ----------- | ------------------------------------------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **elixir**  | `^(lib/\|test/\|config/\|mix\.exs\|mix\.lock\|priv/repo/migrations/\|priv/gettext/\|\.credo\.exs\|\.formatter\.exs\|\.sobelow-conf)` | `mix format --check-formatted`<br>`mix credo --strict`<br>`mix sobelow --compact --exit`<br>`mix gettext.extract --check-up-to-date`<br>`mix deps.unlock --unused` †<br>`mix test` |
| **shell**   | `^(scripts/\|\.shellcheckrc)`                                                                                                        | `fd . 'scripts/' --exclude '*.hurl' -t file --exec shellcheck --color`                                                                                                             |
| **assets**  | `^(assets/\|\.pi/extensions/.*\.(ts\|js\|json)$)`                                                                                    | `prettier --check 'assets/css/**/*.css' 'assets/js/**/*.js' '.pi/extensions/**/*.{ts,js,json}' '!.pi/extensions/**/node_modules/**'`                                               |
| **docs**    | `^(docs/\|README\.md\|AGENTS\.md)`                                                                                                   | `prettier --check 'docs/**/*.md' 'docs/**/*.livemd' 'README.md' 'AGENTS.md'`                                                                                                       |
| **backlog** | `^backlog/`                                                                                                                          | `prettier --check 'backlog/archive/**/*.md' 'backlog/completed/**/*.md' 'backlog/tasks/**/*.md' 'backlog/docs/**/*.md'`                                                            |
| **presto**  | `^presto/`                                                                                                                           | `cd presto && mise run test`                                                                                                                                                       |
| **docker**  | `^(Dockerfile\|\.dockerignore\|compose\.yaml)`                                                                                       | `mise run dev:validate-docker-image` (only if `Dockerfile` in staged files)                                                                                                        |

> **† `mix deps.unlock --unused` sub-gate**: Although listed under the elixir category, this check has an additional sub-gate — it runs only when `mix.exs` or `mix.lock` is in the staged files, not on every Elixir change. This is because an unused dependency can only be introduced by changing the dependency specification, not by changing application code.

If no files match any category (e.g., `git commit --allow-empty`), the script exits early with a message.

## Implementation Steps

### Step 1: Restructure `scripts/dev/precommit`

Read staged file list from `$STAGED` (already exported by `.git/hooks/pre-commit`). Replace the linear execution with conditionally-guarded blocks using the structure:

```bash
if echo "$STAGED" | grep -qE '<category-pattern>'; then
  debug_msg "Running <check description>..."
  <check command>
fi
```

Each guard tests whether any staged file matches its category pattern. Each check block runs independently — `set -e` ensures fail-fast behaviour (unchanged from current).

**Key design decisions**:

- Prettier blocks are split so each glob group runs only when its category has changes (backlog→backlog prettier, docs→docs prettier, assets→assets/pi prettier). This avoids running prettier on `docs/` when only `backlog/` changed, and vice versa.
- The assets prettier command excludes `node_modules` inside `.pi/extensions/` via the `'!.pi/extensions/**/node_modules/**'` negation pattern (prettier supports `.gitignore`-style negation).
- The docs prettier command now includes `AGENTS.md` alongside `README.md` and docs globs.
- `mix test` runs as `mix test` (same as current) — not partitioned. The pre-commit is for fast feedback; partitioning is a CI concern.
- `mix deps.unlock --unused` has a **sub-gate** on `mix.exs` or `mix.lock` changes specifically (not all Elixir changes). See the footnote in the category table.
- `mix gettext.extract --check-up-to-date` gates on Elixir changes (it needs compiled code, so any Elixir change could affect gettext extraction).

**Update the `#MISE description` comment** at the top of the script to: `"Run checks before a commit (conditional on staged file types)"`.

**File**: `scripts/dev/precommit`

**Verification**:

- Stage only a `backlog/tasks/*.md` file: `git add backlog/tasks/some-task.md && mise run dev:precommit`. Confirm only prettier on backlog runs. Confirm `mix test` does NOT run.
- Stage only a `presto/main.py` file: confirm only presto pytest runs.
- Stage only a `lib/music_library/records.ex` file: confirm all Elixir checks run. Confirm `mix deps.unlock --unused` does **NOT** run (sub-gate: mix.exs/mix.lock not staged).
- Stage `mix.exs` only: confirm `mix deps.unlock --unused` **does** run. Confirm other Elixir checks run. Confirm `mix test` runs (any Elixir change triggers tests).
- Stage files from all categories simultaneously: confirm all checks run.
- `git commit --allow-empty -m "test"`: confirm script exits early without errors.

### Step 2: Add presto test check

Add a guard for `^presto/` that runs `cd presto && mise run test`. This uses the presto mise task defined in `presto/mise.toml` (`pytest tests/ -v`).

**Verification**: Stage `presto/main.py`, run precommit, confirm pytest executes.

### Step 3: Add Docker image validation

Add a guard for `Dockerfile` changes that runs `mise run dev:validate-docker-image`. This check already exists in CI lint; adding it to pre-commit catches builder image problems before push.

**Verification**: Stage `Dockerfile`, run precommit, confirm validate-docker-image executes.

### Step 4: Manual integration test

Run through each category in isolation and combined:

```bash
# Elixir-only (without mix.exs/mix.lock — deps.unlock should NOT run)
git add lib/music_library/records.ex && mise run dev:precommit

# Elixir dependency change (deps.unlock SHOULD run)
git add mix.exs && mise run dev:precommit

# Docs-only
git add docs/architecture.md && mise run dev:precommit

# AGENTS.md (docs category, must trigger docs prettier including AGENTS.md)
git add AGENTS.md && mise run dev:precommit

# Backlog-only
git add backlog/tasks/some-task.md && mise run dev:precommit

# Presto-only
git add presto/main.py && mise run dev:precommit

# Shell-only
git add scripts/dev/precommit && mise run dev:precommit

# Docker-only
git add Dockerfile && mise run dev:precommit

# All categories
git add lib/ test/ scripts/ docs/ backlog/ presto/ Dockerfile && mise run dev:precommit
```

**Verification**: For each case, observe which checks run (via `debug_msg` output) and confirm only expected checks execute.

### Step 5: Update documentation

- **`docs/project-conventions.md`**: Add a "Pre-commit Hooks" subsection under "Workflow" documenting the conditional check behavior and the file-to-check mapping table. Copy the category table from this plan (including the `deps.unlock` sub-gate footnote). Add a note that CI always runs the full suite unconditionally.
- **`docs/available-tasks.md`**: Update the `dev:precommit` description from `"Run checks before a commit"` to `"Run checks before a commit (conditional on staged file types)"`.

## Architecture Impact Analysis

| Touchpoint              | Impact                                                                               |
| ----------------------- | ------------------------------------------------------------------------------------ |
| `.git/hooks/pre-commit` | No change — already exports `$STAGED` and delegates to `mise run dev:precommit`      |
| `scripts/dev/precommit` | **Primary change** — restructured from linear to conditional execution               |
| `scripts/_helpers.sh`   | No change needed                                                                     |
| `mise.toml`             | No change — `dev:precommit` task definition unchanged (runs `scripts/dev/precommit`) |
| `presto/mise.toml`      | No change — `test` task already exists                                               |
| CI workflows            | No change — CI runs full suite unconditionally (correct for CI)                      |
| Supervision tree        | No impact                                                                            |
| PubSub topics           | No impact                                                                            |
| Schemas / contexts      | No impact                                                                            |
| External APIs           | No impact                                                                            |
| Routes / UI components  | No impact                                                                            |

## Performance Profile

| Scenario                 | Before                | After                  | Improvement   |
| ------------------------ | --------------------- | ---------------------- | ------------- |
| Backlog/doc change only  | ~minutes (full suite) | ~2 seconds (prettier)  | ~100x         |
| Presto change only       | ~minutes (full suite) | ~10 seconds (pytest)   | ~10x          |
| Shell script change only | ~minutes (full suite) | ~1 second (shellcheck) | ~100x         |
| Dockerfile change only   | ~minutes (full suite) | ~3 seconds (validate)  | ~50x          |
| Elixir change            | ~minutes (full suite) | ~minutes (full Elixir) | No regression |
| All categories           | ~minutes (full suite) | ~minutes (full suite)  | No regression |

**Runtime complexity**: O(1) — grep on the staged file list is a single pass. Each check block is independently gated.

**Database query patterns**: Unchanged. Tests still run the same queries when they execute.

**Memory footprint**: Unchanged — bash script, no persistent state.

## Production Changes

None. This is a local development tooling change. The pre-commit hook only runs on developer machines, never in production or CI.

## Documentation Updates

1. **`docs/project-conventions.md`**: Add a "Pre-commit Hooks" subsection under "Workflow" with:
   - Description of conditional check behavior
   - File-to-check mapping table (same as above, including deps.unlock sub-gate footnote)
   - Note that CI always runs the full suite

2. **`docs/available-tasks.md`**: Update `dev:precommit` description from `"Run checks before a commit"` to `"Run checks before a commit (conditional on staged file types)"`
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Original Draft Notes

Current state: pre-commit hooks run the entire verification suite irrespective of the change.

Annoyances identified:

1. Changes to /backlog items only need the pretty linter.
2. Changes to documentation only need the pretty linter.
3. Changes to the presto application only need to run the presto test suite.
4. Possibly some other patterns, need to verify the complete repo structure.

## Analysis Summary

### Current pre-commit flow

1. `.git/hooks/pre-commit` gathers staged files via `git diff-index --cached --name-only HEAD`, exports `$STAGED` and `$MISE_PRE_COMMIT=1`, then runs `mise run dev:precommit`
2. `scripts/dev/precommit` runs all checks linearly: shellcheck → credo → sobelow → gettext → format → prettier → deps.unlock → tests
3. No inspection of `$STAGED` — all checks run always

### File categories identified in repo

- **Elixir**: `lib/`, `test/`, `config/`, `priv/repo/migrations/`, `priv/gettext/`, `mix.exs`, `.credo.exs`, `.formatter.exs`, `.sobelow-conf`
- **Shell**: `scripts/`, `.shellcheckrc`
- **Assets/JS/CSS**: `assets/`, `.pi/extensions/`
- **Documentation**: `docs/`, `README.md`, `AGENTS.md`
- **Backlog**: `backlog/`
- **Presto (MicroPython)**: `presto/`
- **Docker/Infra**: `Dockerfile`, `.dockerignore`, `compose.yaml`
- **Config/misc**: `mise.toml`, `.gitignore` (fall through to Elixir checks since these affect the build)

### Presto test suite

- Lives in `presto/tests/` (Python, pytest)
- Runnable via `cd presto && mise run test` (uses monorepo config root)
- Already exists and is functional

### Docker validation

- `mise run dev:validate-docker-image` exists and is used in CI
- Not currently in pre-commit — adding it closes a CI→local gap
<!-- SECTION:NOTES:END -->
