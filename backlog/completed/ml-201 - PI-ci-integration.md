---
id: ML-201
title: PI ci integration
status: Done
assignee:
  - "@pi"
created_date: "2026-06-02 06:25"
updated_date: "2026-06-02 20:13"
labels:
  - pi
  - ci
  - extension
dependencies: []
documentation:
  - doc-32 - ML-201-Research-CI-integration-routes.md
modified_files:
  - .gitignore
  - .pi/extensions/ci-browser/index.ts
  - .pi/extensions/ci-browser/ci-client.ts
  - .pi/extensions/ci-browser/format.ts
  - .pi/extensions/ci-browser/ci-client.test.ts
  - .pi/extensions/ci-browser/format.test.ts
  - .pi/extensions/ci-browser/index.test.ts
  - .pi/extensions/ci-browser/package.json
  - .pi/extensions/ci-browser/package-lock.json
  - .pi/extensions/ci-browser/tsconfig.json
  - scripts/dev/pi-test
  - .github/workflows/pi.yml
  - docs/architecture.md
  - docs/production-infrastructure.md
priority: medium
ordinal: 34000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Create a pi extension for browsing CI results and monitoring CI run execution via the `gh` command-line utility.

Required capabilities:

1. Show past CI runs.
2. Open a run and view its results.
3. Based on the current branch, find whether there is a run to watch and watch it.
4. Expose the functionality both through the pi TUI and as tools usable by the LLM.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Project-local pi CI extension exposes an interactive `/ci` command that lists recent GitHub Actions workflow runs using the `gh` CLI and shows workflow, branch, status/conclusion, title, age, and run identifier.
- [ ] #2 Opening a run from the TUI displays structured run details, including jobs/steps status, attempt, URL, timestamps, and a bounded failed-log view for failed runs.
- [ ] #3 The TUI can detect the current git branch, find the newest watchable run for that branch, and watch it until completion or user cancellation with visible progress updates.
- [x] #4 LLM tools are registered for listing runs, viewing a run, finding the current-branch run, watching a specific run, and watching the current-branch run.
- [x] #5 Tool outputs are concise, structured for agent use, and truncate large logs/output at the project pi tool limit while preserving enough metadata to continue investigation.
- [ ] #6 Missing prerequisites and expected edge cases are handled clearly: not in a git repo, `gh` missing, unauthenticated `gh`, no runs found, no active branch run, invalid run ID, cancelled watch, and timed-out watch.
- [x] #7 Helper-level tests cover `gh` JSON parsing, run filtering/selection, formatting/truncation, watch polling terminal states, cancellation, timeout, and representative CLI error handling.
- [x] #8 The new extension tests run through `scripts/dev/pi-test` and `.github/workflows/pi.yml`.
- [x] #9 Relevant project documentation is updated to describe the CI pi extension and any CI/test workflow changes.

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

# Implementation Plan — Route B (amended): structured `gh --json` adapter plus native TUI/browser watch

Route B was selected after reviewing `doc-32 - ML-201-Research-CI-integration-routes.md`. This amended plan keeps Route B, adds concrete polling bounds, clarifies current-branch run selection, and tightens pi tool/TUI/test requirements.

## Objective alignment

ML-201 asks for a pi extension that uses the GitHub CLI (`gh`) to browse CI results and monitor run execution, exposed both as an interactive TUI command and as LLM-callable tools.

This plan maps the objective to one shared structured adapter:

- **Show past runs** → `ci_list_runs` helper/tool and `/ci` list view call `gh run list --json ...` with bounded defaults.
- **Open a run and see results** → `ci_view_run` helper/tool and TUI detail view call `gh run view <run-id> --json ...`, showing run/job/step metadata and optional failed logs.
- **Find/watch current-branch run** → helper reads the current branch and HEAD SHA, prefers watchable runs for the current commit, falls back to watchable branch runs, then polls `gh run view --json` until terminal state, cancellation, or timeout.
- **TUI and LLM surfaces** → tools and `/ci` command share the same helper and formatter modules so behavior stays consistent.

## Chosen approach and alternatives considered

**Chosen approach: Route B — structured `gh --json` adapter plus native TUI browser/watch.** Add a project-local extension under `.pi/extensions/ci-browser/` with typed helper functions around `gh` JSON output. The TUI command and LLM tools both call the same helpers and formatters.

This is the simplest viable route that satisfies all requirements: it uses `gh`, avoids fragile parsing of human CLI text, gives the TUI structured data to render, and lets tools return concise agent-friendly summaries.

Alternatives evaluated:

- **Route A — thin `gh` wrapper:** rejected as primary route because raw `gh run watch` output is hard to render incrementally through `pi.exec()`, raw CLI text is harder for tools to summarize reliably, and branch-run selection logic is less testable.
- **Route C — `gh pr checks` first:** deferred as optional future fallback because it is PR/check-centric rather than run-centric. It does not fully satisfy “open a run and see results,” and branches without PRs or push-only runs are not covered well.
- **Route D — direct GitHub API / `gh api`:** rejected for initial implementation because it increases auth/API maintenance and duplicates `gh run` behavior despite the requirement to use `gh`.
- **Route E — reusable pi package:** deferred until the project-local extension proves useful. Packaging/versioning adds overhead not required to deliver ML-201.

## Architecture impact analysis

- **Project-local pi extension:** add `.pi/extensions/ci-browser/` with `index.ts`, `ci-client.ts`, `format.ts`, tests, `package.json`, and a lockfile when dependencies are declared.
- **Shared helper boundary:** `ci-client.ts` exposes testable functions and accepts an injected exec function so unit tests do not need network access, `gh`, or GitHub authentication.
- **LLM tools:** register `ci_list_runs`, `ci_view_run`, `ci_find_current_branch_run`, `ci_watch_run`, and `ci_watch_current_branch` with bounded schemas, prompt snippets, and prompt guidelines.
- **TUI command:** register `/ci`; check `ctx.hasUI` before opening UI and show a clear error/fallback message in non-interactive modes.
- **CLI integration:** use `pi.exec("gh", ...)` and `pi.exec("git", ...)`; do not call GitHub APIs directly except through `gh` commands.
- **Imports/dependencies:** follow existing project-local extension import style unless the current pi package version requires a newer namespace. Keep runtime dependencies minimal, but declare explicit package dependencies for modules that tests import directly (for example pi packages, `typebox`, and `pi-ai` for `StringEnum`) so `npm ci --prefix .pi/extensions/ci-browser` is reproducible.
- **Test/CI workflow:** update `scripts/dev/pi-test` and `.github/workflows/pi.yml` to run the new extension tests.
- **Documentation:** update project docs for the new pi CI tooling and CI workflow coverage.
- **Phoenix app schemas/contexts/routes:** no changes.
- **Database/PubSub/supervision/Oban:** no changes.
- **External application APIs:** GitHub is accessed only through the user’s local `gh` authentication; no server-side app integration is added.
- **Production runtime:** no application deployment/runtime changes.

## Key implementation decisions

### Tool and command names

- Command: `/ci`.
- Tools: `ci_list_runs`, `ci_view_run`, `ci_find_current_branch_run`, `ci_watch_run`, `ci_watch_current_branch`.

### Run fields

Use the documented `gh` JSON fields from the research document:

- List: `attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,startedAt,status,updatedAt,url,workflowDatabaseId,workflowName`.
- Detail: same fields plus `jobs`.

Add optional `attempt` support to `ci_view_run` and the helper because `gh run view <run-id> --attempt <n>` is supported and the detail view displays attempt metadata.

### Current-branch selection policy

`findCurrentBranchRun()` should read both:

- current branch: `git branch --show-current`
- current commit: `git rev-parse HEAD`

Selection order:

1. List recent runs for **current branch + current HEAD SHA** and choose the newest watchable run.
2. If none exist, list recent runs for **current branch** and choose the newest watchable run. Mark the result as a branch fallback and include the run SHA so the user/agent can see whether it differs from HEAD.
3. If no watchable run exists, return a normal “no active run” result with the latest completed branch run as context when available.

Watchable statuses: `queued`, `in_progress`, `requested`, `waiting`, `pending`.

Terminal polling state: treat `status === "completed"` as terminal and use `conclusion` to report success/failure/cancelled/skipped/timed out. Preserve unknown statuses in output rather than assuming success.

### Polling profile

Default tool watch settings:

- `intervalSeconds`: default `10`, minimum `5`, maximum `60`.
- `timeoutSeconds`: default `1800` (30 minutes), minimum `30`, maximum `3600` (1 hour).

Default TUI watch interval is also 10 seconds, with user cancellation via Escape/Ctrl+C and the same safety timeout unless the implementation exposes a visible override.

Estimated API/CLI usage:

- 30 minutes at 10 seconds → about 180 `gh run view --json ...` calls.
- 1 hour at 5 seconds → up to about 720 calls.

The implementation must avoid concurrent watches from one command/tool and must stop polling immediately on terminal status, cancellation, or timeout.

### Failed logs

Failed logs are optional and off by default. Fetch them only when `includeFailedLog` is requested or the TUI failed-log action is used.

`gh run view --log-failed` may be slower and may fail independently from the structured run detail. The helper should keep the main detail result useful even if failed-log retrieval fails, and the formatter should show a clear failed-log error note rather than discarding the run detail.

### Tool schema and error semantics

- Use `StringEnum` from `pi-ai` for string enum parameters instead of Typebox literal unions, following pi’s Google-compatible schema guidance.
- Add numeric bounds/default descriptions for `limit`, `intervalSeconds`, `timeoutSeconds`, and any log limits.
- Expected non-error states return normal explanatory tool results: no runs found, no active branch run, timeout with last snapshot, and user/agent cancellation.
- CLI/user-input failures that cannot produce the requested data are normalized into friendly error classes/messages and thrown from tool `execute()` so pi marks the tool result as an error: `gh` missing, unauthenticated `gh`, invalid run ID, JSON parse failure, and unexpected nonzero `gh` exits.
- The TUI catches the same normalized errors and renders clear empty/error states without crashing.

## Performance profile

- **Runtime complexity:** listing is O(r) for the bounded run count; viewing is O(j + s) for jobs and steps returned by one run; watching is O(p × (j + s)) where `p` is the number of polling iterations.
- **Database query pattern:** no database access is introduced, so there are no SQLite query patterns or DB N+1 risks.
- **GitHub/CLI call pattern:**
  - List view/tool: one `gh run list --json ...` call per refresh.
  - Detail view/tool: one `gh run view --json ...` call, plus at most one optional `gh run view --log-failed` call.
  - Current-branch find: one or two bounded `gh run list --json ...` calls after local `git` branch/SHA checks.
  - Watch: one `gh run view --json ...` call per poll interval until terminal status, cancellation, or timeout.
- **N+1 risk:** avoid per-job `gh` calls in default detail view. Use run-level JSON fields from one command. Fetch logs only on explicit failed-log request.
- **Memory footprint:** bounded run lists, structured detail for one run, and truncated log strings. Do not store historical run data in session state beyond normal tool/TUI state.
- **Latency:** list/detail latency is dominated by `gh` startup and GitHub API response. TUI should show a loader while commands run. Watch latency is bounded by polling interval.
- **Throughput/rate-limit implications:** watch mode repeatedly invokes `gh`; the defaults are conservative and bounded. Tool outputs should report polling settings so agents understand quota impact.

## Benchmarking requirements

No ongoing benchmark is required because this is a local developer/agent extension and all expensive work is bounded `gh` invocation.

One-off validation during implementation:

1. Measure a normal `gh run list --limit 20 --json ...` call in this repository. If it consistently exceeds 5 seconds on a healthy connection, keep the loader and consider reducing the default limit.
2. Measure `gh run view <run-id> --json ...` for a representative completed run. Formatted output should remain well under the 50KB/2000-line tool limit without logs.
3. Verify failed-log output is truncated with an explicit notice and, where practical, the full failed-log output saved to a temp file for follow-up reading.
4. Verify watch polling uses one `gh run view --json ...` call per interval and stops immediately on terminal status, cancellation, or timeout.

Acceptable threshold: default list/detail tools return bounded output without truncation in normal cases; failed logs may truncate; watch mode does not poll more often than configured.

## Cost profile

No paid application resources are introduced.

- **GitHub:** uses the developer’s authenticated `gh` CLI and normal GitHub Actions/API quotas. Repeated watch polling consumes GitHub API quota: default 30-minute watch ≈ 180 calls, worst allowed 1-hour/5-second watch ≈ 720 calls.
- **Compute:** local machine CPU/process startup for `git` and `gh` commands only.
- **Storage:** no persistent app storage; optional temp files only for large truncated logs.
- **Third-party services:** no new paid service accounts, tokens, or API integrations are required.

## Production changes / manual steps

No manual production runtime changes are required.

- **Environment variables:** none for the deployed Phoenix app.
- **Local prerequisite:** pi users need `gh` installed and authenticated (`gh auth status` / `gh auth login`). `mise.toml` already provisions `gh` locally.
- **Service provisioning:** none.
- **Database migrations:** none.
- **DNS/firewall:** none.
- **Deployment config:** no Coolify or production server config changes.
- **CI workflow:** `.github/workflows/pi.yml` will be updated to test the new extension. This affects repository CI only, not production runtime.
- **Rollout:** merge through normal PR/CI. Users reload pi extensions with `/reload` or restart pi to pick up `/ci` and tools.
- **Rollback:** revert code/workflow changes. No data or production state rollback is required.

## Documentation updates

- `docs/architecture.md`: add/extend a concise project tooling / pi extensions note so future agents know `.pi/extensions/ci-browser` exists and what it provides.
- `docs/production-infrastructure.md`: update the CI/CD or pi coding-agent tooling section to mention the CI browser extension, local `gh` dependency, and `.github/workflows/pi.yml` test coverage.
- `docs/available-tasks.md`: update only if implementation changes mise task definitions or descriptions.
- `.pi/extensions/ci-browser/README.md`: optional but recommended if command/tool usage, keybindings, or troubleshooting are not self-evident from tool descriptions and docs updates.
- No Phoenix API docs or user-facing web docs are expected.

## Sequential implementation steps with verification

1. **Create the extension skeleton and shared type boundaries.**
   - Add `.pi/extensions/ci-browser/package.json`, lockfile when dependencies are declared, `index.ts`, `ci-client.ts`, `format.ts`, and focused tests.
   - Define TypeScript interfaces for run list items, run details, jobs, steps, watch state, current-branch selection result, and normalized CLI errors.
   - Add an injected exec abstraction so helper tests can fake `git`/`gh` output without network access.
   - Keep extra dependencies minimal, but make package/test dependencies explicit and reproducible.
   - Verification before moving on: run the new extension npm test command with placeholder/helper tests and run Prettier on `.pi/extensions/ci-browser/**/*.ts` / `package.json`.

2. **Implement the structured `gh`/`git` helper layer.**
   - Implement `currentRepoContext()` with `git branch --show-current` and `git rev-parse HEAD`, with clear handling for detached HEAD and non-repo states.
   - Implement `listRuns()` using `gh run list --json` with bounded `limit` and optional branch/status/workflow/commit filters.
   - Implement `viewRun()` using `gh run view <run-id> --json`, optional `--attempt`, and optional failed-log fetch via `gh run view <run-id> --log-failed`.
   - Implement `findCurrentBranchRun()` using the selection policy above: current branch+HEAD first, then branch fallback, then no-active-run with latest completed context.
   - Implement `pollRunUntilDone()` using repeated `viewRun()` calls, abort-signal checks, configurable interval/timeout, progress callbacks, and terminal-status detection.
   - Normalize expected CLI failures (`gh` missing, auth failure, invalid run id, JSON parse failure, no repo/current branch failure) into specific error messages/classes.
   - Verification before moving on: unit tests with fake exec results cover valid JSON parsing, invalid JSON, nonzero `gh` exits, no repo/current branch failure, detached HEAD, no runs, current-HEAD selection, branch fallback selection, latest completed fallback, terminal statuses, cancellation, timeout, and representative CLI errors.

3. **Implement formatting and truncation helpers.**
   - Format run lists with run id, workflow/name, title, branch, short SHA, status/conclusion, age/timestamps, attempt, and URL where useful.
   - Format run details with jobs/steps while keeping default detail output bounded.
   - Format watch progress snapshots for tool `onUpdate` and TUI status lines.
   - Apply pi truncation helpers to failed logs and any large formatted output, with a clear truncation notice and temp-file path for full failed logs when practical.
   - Verification before moving on: tests cover success/failure/pending labels, unknown/missing fields, bounded list output, failed-log truncation, temp-file/truncation notice behavior where implemented, and stable agent-readable tool formatting.

4. **Register LLM tools.**
   - Add `ci_list_runs`, `ci_view_run`, `ci_find_current_branch_run`, `ci_watch_run`, and `ci_watch_current_branch` in `index.ts`.
   - Use Typebox object schemas with `StringEnum` for string enums and bounded numeric options for limits/timeouts/intervals.
   - Add prompt snippets and guidelines so tools are discoverable for CI status questions.
   - Return normal explanatory results for no-run, timeout, and cancellation states; throw normalized command/input failures so pi marks them as tool errors.
   - Stream watch progress with `onUpdate` and return final run status/conclusion plus polling metadata.
   - Verification before moving on: add a fake `ExtensionAPI` registration smoke test that imports `index.ts` and asserts `/ci` plus all five tools are registered with expected names and schemas; manually confirm tool names appear in a reloaded pi session if practical.

5. **Implement the `/ci` TUI command.**
   - Check `ctx.hasUI`; if false, notify/return that `/ci` requires interactive mode and suggest LLM tools for non-interactive use.
   - On `/ci`, load recent runs with `BorderedLoader` and show a navigable run list.
   - Enter opens a structured detail view for the selected run.
   - Provide keys for refresh, back, quit, copy run id/URL, failed-log view for failed runs, watch selected run, and watch current branch.
   - Watch mode updates visible progress on each poll and remains cancellable with Escape/Ctrl+C.
   - Handle empty/error states in the UI without crashing.
   - Verification before moving on: manual TUI smoke test in this repository: `/ci` opens, list renders, refresh works, a run opens, failed-log action is safe on failed/no-failed runs, current-branch watch reports either an active run or a clear no-active-run state, and cancellation returns to the previous view.

6. **Wire tests into project commands and GitHub Actions.**
   - Add an npm `test` script in `.pi/extensions/ci-browser/package.json` using Node’s built-in test runner, matching existing extension conventions.
   - Add/commit a lockfile when package dependencies are declared so CI can use `npm ci`.
   - Update `scripts/dev/pi-test` to run the new extension tests.
   - Update `.github/workflows/pi.yml` to install/test the new extension alongside existing pi extension tests.
   - Verification before moving on: run `mise run dev:pi-test`; inspect the updated `.github/workflows/pi.yml` commands; confirm tests do not require network, `gh`, or GitHub authentication.

7. **Update documentation.**
   - Update `docs/architecture.md` and/or `docs/production-infrastructure.md` as described above.
   - Add `.pi/extensions/ci-browser/README.md` if command/tool usage, keybindings, or troubleshooting need more detail than project docs and tool descriptions provide.
   - Verification before moving on: run Prettier on changed Markdown files and confirm docs accurately name `/ci`, the five tools, the local `gh` auth dependency, and the pi extension test workflow.

8. **Run final focused verification.**
   - Run `mise run dev:pi-test`.
   - Run Prettier/format checks for changed `.pi/extensions` and docs files.
   - Run `gh auth status` and a real `gh run list --limit 5 --json databaseId,status,conclusion,workflowName,headBranch,displayTitle,createdAt,url` smoke command to confirm local prerequisites.
   - Reload pi and manually verify `/ci` plus at least `ci_list_runs` and `ci_view_run` against this repository.
   - If a run is active for the branch/current HEAD, verify watch to terminal status or cancellation; if none is active, verify the no-active-run path includes latest completed branch context.
   - Completion gate: all focused tests pass, TUI and tools satisfy the acceptance criteria, and no production/runtime changes are needed.

Review remediation plan: fix failed-log truncation to preserve useful content for long single lines, make watch polling honor timeout before each subsequent `gh run view`, and add an index-level smoke test that imports the extension and asserts registration of all CI tools plus `/ci`.

Watch output follow-up: include job/step details in watch progress/final output by formatting current run detail during watch instead of only the compact status line. Update tests to assert watch results/progress include representative job/step names, then run ci-browser and pi extension tests.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Steps 1-3 complete: Extension skeleton, ci-client.ts (structured gh/git helper layer with injected exec), format.ts (formatting/truncation helpers). All 67 tests pass covering: JSON parsing, run filtering/selection, formatting, truncation, watch polling terminal states, cancellation, timeout, and representative CLI error handling.

Steps 4-6 complete: All 5 LLM tools registered with Typebox schemas, StringEnum, prompt snippets, prompt guidelines, truncation, and onUpdate streaming. /ci TUI command implemented with SelectList-based run browser, detail view with jobs/steps, watch mode, refresh, failed-log view, and current-branch watch. Tests wired into scripts/dev/pi-test and .github/workflows/pi.yml. All 67 extension tests pass alongside existing extensions.

Step 7 complete: Updated docs/architecture.md with new 'Project Tooling (pi Extensions)' section listing ci-browser alongside existing extensions. Updated docs/production-infrastructure.md Pi coding agent tools table with ci-browser tools and gh dependency. AC #1-#3 and #6 are implemented in code but require manual TUI smoke test verification.

Addressing review findings from ML-201 implementation review.

Review findings fixed: long single-line failed logs now preserve a UTF-8-safe prefix instead of truncating to empty output; watch polling now caps each sleep to remaining timeout and rechecks timeout before another `gh run view`; index-level smoke tests import the extension and assert registration of all CI tools plus `/ci`. `scripts/dev/pi-test` now installs locked npm dependencies when missing so the new index smoke test can run from a clean checkout.

User reported watch output only shows run status and not steps. Reopening ML-201 to address watch visibility.

Watch visibility follow-up complete: watch progress and final watch output now include job and step details; the TUI watch screen updates with the same formatted run progress instead of a status-only line. Tests assert watch progress/result output includes representative job and step names. Verification: `scripts/dev/pi-test` passes.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Created `.pi/extensions/ci-browser/` — a project-local pi extension for browsing GitHub Actions CI runs via the `gh` CLI.

Key pieces:

- `ci-client.ts` provides the typed helper layer around `gh`/`git`, including run listing, run detail, failed-log retrieval, current-branch selection, polling, and normalized CLI error classes.
- `format.ts` formats run lists/details/watch output and bounds failed-log output with truncation notices.
- `index.ts` registers `/ci` plus five LLM tools: `ci_list_runs`, `ci_view_run`, `ci_find_current_branch_run`, `ci_watch_run`, and `ci_watch_current_branch`.
- Tests cover helper behavior, formatting/truncation, watch cancellation/timeout, extension registration via `index.test.ts`, and watch output including job/step details.
- `scripts/dev/pi-test` and `.github/workflows/pi.yml` run the ci-browser tests; the extension has a small `typebox` lockfile/dependency so the index smoke test can run from a clean checkout.
- Project docs were updated in `docs/architecture.md` and `docs/production-infrastructure.md`.

Review/follow-up fixes:

- Oversized single-line failed logs now preserve a UTF-8-safe prefix instead of returning empty truncated output.
- Watch polling now sleeps only until the remaining timeout and rechecks timeout before issuing another `gh run view`, avoiding extra polls after timeout.
- Added `index.test.ts` to import the extension and verify all CI tools plus `/ci` are registered.
- Watch progress, TUI watch updates, and final watch results now include job and step details rather than status-only output.

Verification: `scripts/dev/pi-test` passes (41 sensitive-file-guard + 29 s3-browser + 70 ci-browser tests).

Follow-up risk: `/ci` TUI paths are code-complete but still need a manual smoke test in a running pi session for AC #1-#3/#6.

<!-- SECTION:FINAL_SUMMARY:END -->
