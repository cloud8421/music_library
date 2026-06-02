---
id: doc-32
title: "ML-201 Research: CI integration routes"
type: specification
created_date: "2026-06-02 06:29"
updated_date: "2026-06-02 06:33"
tags:
  - research
  - pi-extension
  - ci
  - github-actions
---

# ML-201 Research: PI CI integration implementation routes

## Problem and objective

ML-201 asks for a pi extension that uses the GitHub CLI (`gh`) to browse CI results and monitor CI execution. The extension must support both interactive TUI use and LLM-callable tools.

Required capabilities:

1. Show past CI runs.
2. Open a run and view its results.
3. From the current git branch, find whether there is a CI run to watch and watch it.
4. Expose the same capability through pi TUI commands and custom tools.

## Existing project context

- Project-local pi extensions already live under `.pi/extensions/`.
- Existing extension patterns worth reusing:
  - `.pi/extensions/prod-errors/index.ts`: multiple LLM tools plus `/prod-errors` TUI browser.
  - `.pi/extensions/prod-logs/index.ts`: LLM tool plus scrollable `/prod-logs` TUI viewer, output truncation, refresh/copy interactions.
  - `.pi/extensions/s3-browser/index.ts`: command-only TUI using `BorderedLoader`, `SelectList`, and local helper modules.
- Existing CI helper `scripts/ci/watch` currently runs `gh run watch` without selecting a run.
- `mise.toml` already provisions `gh = 'latest'`.
- `.github/workflows/pi.yml` tests pi extensions, currently only `sensitive-file-guard` and `s3-browser` have npm tests wired into CI.

## Pi extension capabilities relevant to this task

From pi extension documentation and examples:

- `pi.registerTool()` exposes custom tools to the LLM.
- `pi.registerCommand()` exposes slash commands in the TUI.
- `ctx.ui.custom()` supports custom TUI components with keyboard input.
- `BorderedLoader`, `SelectList`, `SettingsList`, `Text`, and low-level components from `@earendil-works/pi-tui` / the currently used project import namespace can be reused.
- Tools should truncate large output at the usual 50KB / 2000-line limit using pi truncation helpers.
- Commands must check `ctx.hasUI` before opening TUI-only interactions.
- Tools can stream progress to the TUI/agent using `onUpdate`, but `pi.exec()` returns final command output rather than a live stdout stream. Native polling can provide better watch progress than shelling directly to `gh run watch`.

## `gh` capabilities relevant to this task

Verified from local `gh --help` output:

- `gh run list --json attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,name,number,startedAt,status,updatedAt,url,workflowDatabaseId,workflowName --branch <branch> --limit <n>` lists runs with structured fields.
- `gh run view <run-id> --json attempt,conclusion,createdAt,databaseId,displayTitle,event,headBranch,headSha,jobs,name,number,startedAt,status,updatedAt,url,workflowDatabaseId,workflowName` gives structured detail including jobs.
- `gh run view <run-id> --log-failed` can return failed logs; full logs are available with `--log` but can be large.
- `gh run watch <run-id> --compact --exit-status` watches a run to completion, but the command notes it does not support fine-grained PATs because `checks:read` permission is unavailable for that mode.
- `gh pr checks --json bucket,completedAt,description,event,link,name,startedAt,state,workflow --watch` is branch/PR-oriented and can be useful for current branch checks, but it is not run-centric.

## Architectural touchpoints

- `.pi/extensions/ci-browser/` or similar new project-local pi extension directory.
- Optional helper modules such as `ci-client.ts`, `format.ts`, and `ci-client.test.ts` if the implementation is split for testability.
- `.pi/extensions/<extension>/package.json` for npm scripts if tests are added.
- `scripts/dev/pi-test` to include the new extension tests.
- `.github/workflows/pi.yml` to run the new extension tests in CI.
- `docs/architecture.md` may need a small update if the project wants architecture docs to track project-local pi extensions and CI tooling.
- No Phoenix schemas, routes, PubSub topics, Oban workers, supervision tree, external application APIs, or production infrastructure are affected.

## Implementation routes

### Route A — thin `gh` command wrapper extension

Build a small project-local extension that shells out to `gh` commands directly.

Potential shape:

- Tools:
  - `ci_list_runs`: wraps `gh run list` with JSON or text output.
  - `ci_view_run`: wraps `gh run view` and optional `--log-failed` / `--log`.
  - `ci_watch_run`: wraps `gh run watch <run-id> --compact --exit-status`.
  - `ci_watch_current_branch`: gets `git branch --show-current`, lists branch runs, picks the newest watchable run, and delegates to `gh run watch`.
- TUI command:
  - `/ci` or `/ci-runs` opens a `SelectList` populated by `gh run list`; selecting an item shows the raw `gh run view` output; a key can start `gh run watch`.

Pros:

- Smallest implementation.
- Stays very close to the user requirement of using `gh`.
- Minimal data modeling and little custom UI logic.

Cons:

- TUI output is mostly raw CLI text and harder to navigate.
- `gh run watch` output is not naturally structured through `pi.exec()`; progress may only appear after the command exits unless a separate process/spawn layer is introduced.
- Harder to test branch/run selection because logic is mixed with CLI output.
- Harder for LLM tools to return concise structured summaries without fragile text parsing.

Best fit:

- Quick utility where raw `gh` output is acceptable and robust TUI watch progress is not required.

### Route B — structured `gh` JSON adapter plus native TUI browser/watch

Build a project-local extension with a typed helper layer around `gh --json` output. Use the same helper functions for both LLM tools and TUI commands.

Potential shape:

- `.pi/extensions/ci-browser/index.ts`: registers tools and commands.
- `.pi/extensions/ci-browser/ci-client.ts`: wraps `pi.exec("gh", ...)` and `pi.exec("git", ...)`, parses JSON, normalizes errors, and exposes functions such as:
  - `listRuns({ branch, limit, status, workflow })`
  - `viewRun(runId, { includeFailedLog })`
  - `findCurrentBranchRun({ watchableStatuses })`
  - `pollRunUntilDone(runId, { intervalMs, timeoutMs, signal, onProgress })`
- `.pi/extensions/ci-browser/format.ts`: converts structured data to concise LLM/TUI text.
- Tools:
  - `ci_list_runs` with filters and bounded defaults.
  - `ci_view_run` with optional failed-log inclusion and output truncation.
  - `ci_find_current_branch_run` returning the selected run or a clear no-run result.
  - `ci_watch_run` and/or `ci_watch_current_branch` polling `gh run view --json` until terminal state, using `onUpdate` for progress.
- TUI command:
  - `/ci` opens a run list with status/conclusion badges, workflow, branch, title, and relative time.
  - Enter opens a structured detail page with jobs/steps and a key for failed logs.
  - A watch key polls the selected run and updates the component until completion.
  - A current-branch action finds the newest queued/in-progress/requested/waiting/pending run for the branch and watches it.

Pros:

- Best alignment with both required surfaces: structured tools and navigable TUI.
- Avoids parsing raw human CLI text.
- Polling via `gh run view --json` gives cancellable, incremental watch updates in both TUI and tools.
- Shared helper code keeps TUI and tools consistent.
- Testable with fake `pi.exec` results and fixture JSON.
- No new runtime dependencies are required.

Cons:

- More code than Route A.
- Polling consumes repeated `gh`/GitHub API calls during watch.
- Logs can still be large; failed logs must be optional and truncated.
- The implementation must define sensible timeouts and terminal status handling.

Best fit:

- Recommended route. It is the simplest approach that still provides a real TUI experience, reliable LLM tool output, branch-aware run selection, and testable code.

### Route C — branch-first PR checks integration with run browser supplement

Use `gh pr checks` as the primary current-branch watch mechanism and keep `gh run list/view` for browsing past runs.

Potential shape:

- `/ci` shows recent runs as in Route A/B.
- Current branch watch runs `gh pr checks --watch --json ...` when the branch has an associated PR.
- Tools include `ci_pr_checks` and `ci_watch_current_branch_checks`.

Pros:

- `gh pr checks` maps directly to “what is happening for the current branch” in a PR workflow.
- It reports required checks and has a documented pending exit code.
- It can be simpler than selecting a specific run for branches with multiple workflows.

Cons:

- Not run-centric; does not directly satisfy “open a run and see results”.
- Branches without PRs, `workflow_dispatch`, and push-only runs are not covered well.
- Check entries link to jobs/checks rather than always to workflow runs.
- Would still need `gh run list/view` for the other requirements.

Best fit:

- Useful as a fallback or supplementary current-branch view, not as the whole implementation.

### Route D — direct GitHub API or `gh api` implementation

Use GitHub REST/GraphQL endpoints directly through `fetch` or `gh api`, building an extension-specific data model without relying on `gh run list/view` wrappers.

Pros:

- Maximum control over queries, pagination, logs, annotations, artifacts, and check/run relationships.
- Could optimize API calls and support richer future functionality.

Cons:

- Highest complexity.
- More auth/scope handling and API-version maintenance.
- Less aligned with the explicit requirement to use the `gh` command-line utility.
- More opportunity to duplicate functionality already provided by `gh`.

Best fit:

- Defer unless `gh run`/`gh pr checks` cannot expose necessary data.

### Route E — reusable pi package instead of project-local extension

Package the CI browser as a reusable pi package installable in other repositories, rather than only adding it under this repository’s `.pi/extensions/` directory.

Pros:

- Portable across projects.
- Cleaner long-term if this is intended as a general pi CI extension.

Cons:

- Packaging, versioning, install, and documentation overhead.
- The current repository already uses project-local `.pi/extensions/` for operational tools.
- It complicates CI/testing before the core UX is validated.

Best fit:

- Follow-up after Route B proves useful, not the initial implementation unless the goal is explicitly cross-project distribution.

## Recommended direction

Choose Route B as the primary implementation, with a small optional Route C fallback for current-branch PR checks only if branch run discovery is insufficient.

This route best satisfies the objective because it maps each requirement to a structured capability:

- Past runs: `gh run list --json` -> typed list in tools and TUI.
- Open run/results: `gh run view --json` plus optional failed-log fetch -> detail view and tool output.
- Watch current branch: `git branch --show-current` + recent branch run filtering + structured polling -> cancellable watcher.
- TUI and LLM tools: both use the same helper functions and formatters.

## Open decisions for plan finalization

1. Command/tool names:
   - Suggested command: `/ci`.
   - Suggested tools: `ci_list_runs`, `ci_view_run`, `ci_find_current_branch_run`, `ci_watch_run`, `ci_watch_current_branch`.
2. Log scope:
   - Default to summary/job detail only.
   - Add `includeFailedLog` option for failed-step logs with truncation.
   - Defer full logs unless explicitly requested because they can be large.
3. Current branch selection policy:
   - Suggested: filter recent branch runs locally and choose the newest run whose `status` is one of `queued`, `in_progress`, `requested`, `waiting`, or `pending`.
   - If none are watchable, return the latest completed branch run as context and say there is no active run.
4. Watch timeout:
   - Suggested default: 30 minutes for tools, user-cancellable in TUI.
   - The tool should accept a shorter timeout for agent-driven checks.
5. Packaging:
   - Suggested initial scope: project-local `.pi/extensions/ci-browser/` with tests wired into `scripts/dev/pi-test` and `.github/workflows/pi.yml`.
