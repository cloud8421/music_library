---
id: ML-160
title: Programmatic access to production logs
status: Done
assignee: []
created_date: "2026-05-04 06:42"
updated_date: "2026-05-04 07:33"
labels: []
dependencies: []
references:
  - "backlog://document/doc-6"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Evaluate and implement the best approach for the LLM to access production logs. The /prod-logs pi extension lets the user see production logs via an interactive TUI, but the LLM has no access beyond the user selecting lines and pasting. The goal is to produce an extension/skill/tool that the LLM can use automatically when it needs to pull production logs. Reading logs from production is already implemented in /prod-logs as a `fetchLogs` function that hits the Coolify API — that code should be reused/shared where possible.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 The LLM can fetch production logs without user intervention by calling the fetch_production_logs tool
- [x] #2 The tool supports a `tail` parameter to limit the number of log lines returned (default: 200)
- [x] #3 The tool supports a `grep` parameter for case-insensitive filtering of log lines
- [x] #4 The tool returns log lines as text the LLM can read and analyze directly in context
- [x] #5 When Coolify credentials are missing, the tool returns a clear error message listing which environment variables are not set
- [x] #6 The existing /prod-logs interactive command continues to work unchanged
- [x] #7 The tool description and guidelines teach the LLM when and how to use it effectively

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

# Implementation Plan

## Route: Pi Tool via `pi.registerTool()` (Route B)

Add a `fetch_production_logs` tool to the existing `prod-logs` pi extension using `pi.registerTool()`. The tool reuses the existing `fetchLogs()` and `resolveVar()` functions at module scope.

---

## Step 1: Add `Type` import and `fetch_production_logs` tool registration

**File**: `.pi/extensions/prod-logs/index.ts`

**Changes**:

1. Add `import { Type } from "typebox";` to the existing imports block
2. Add `import { truncateTail, formatSize, DEFAULT_MAX_BYTES, DEFAULT_MAX_LINES } from "@mariozechner/pi-coding-agent";` to the imports block
3. Inside the `prodLogsExtension()` default export function, add a `pi.registerTool()` call (before or after the existing `pi.registerCommand()` call)

**Tool specification**:

- `name`: `"fetch_production_logs"`
- `description`: Explains when the LLM should use this tool (investigating production errors, checking server behavior, debugging deployed issues). Mentions the 50KB/2000-line truncation limit.
- `promptSnippet`: `"Fetch recent production logs from Coolify (param: tail, grep)"`
- `promptGuidelines`: Three guidelines teaching the LLM when to use the tool, how to grep for relevant lines, and to start with small tail values
- `parameters` (TypeBox schema):
  - `tail` — `Type.Optional(Type.Number())`, default 200, number of most recent log lines
  - `grep` — `Type.Optional(Type.String())`, case-insensitive filter pattern

**Execute handler logic**:

1. Check `signal?.aborted` early — if aborted, return `{ content: [{ type: "text", text: "Cancelled" }] }`
2. Read Coolify credentials via `resolveVar("coolify_host")`, `resolveVar("coolify_app_uuid")`, `resolveVar("coolify_token")`
3. If any credential is missing, return an error message listing which env vars are missing
4. Call `fetchLogs(host, appUuid, token, signal)` — reuses the existing function; `signal` is used for abort support
5. Handle fetch errors: return error text with the error message
6. Handle empty logs: return "No log entries found"
7. Apply grep filter if provided: case-insensitive `includes` match on each line
8. Reverse lines (most recent first — consistent with the existing `/prod-logs` command behavior)
9. Apply tail: `lines.slice(0, tail)` with default 200
10. Join lines with `\n` into a single string
11. Apply output truncation via `truncateTail` with `DEFAULT_MAX_BYTES` (50KB) and `DEFAULT_MAX_LINES` (2000). If truncated, append a note: `"\n\n[Output truncated: X of Y lines (A of B). Use a smaller 'tail' value or narrower 'grep' pattern to reduce output.]"`
12. Return as text content, with `details: { lineCount }` (the pre-truncation line count)

### Verification

1. Run `/reload` in pi to hot-reload the extension
2. Ask the LLM: "What tools are available for fetching production logs?" — it should describe `fetch_production_logs`
3. Ask the LLM: "Fetch the last 50 lines of production logs" — verify it calls the tool and returns log text
4. Ask the LLM: "Fetch production logs containing the word 'error'" — verify filtered output
5. Temporarily unset one Coolify credential and ask the LLM to fetch logs — verify the tool returns a clear error listing which env var is missing
6. Restore the credential, then ask the LLM to fetch logs with `tail: 5000` from a busy period — verify truncation kicks in and the truncation note appears in the output
7. Run `/prod-logs` manually — verify the existing interactive command still works unchanged

---

## Architecture Impact Analysis

| Touchpoint                          | Impact                                                                             |
| ----------------------------------- | ---------------------------------------------------------------------------------- |
| `.pi/extensions/prod-logs/index.ts` | **Modified** — ~70 lines added (imports + tool registration + truncation)          |
| Elixir modules                      | **None** — no changes                                                              |
| Schemas, PubSub, routes, UI         | **None** — pi-only change                                                          |
| Config / env vars                   | **None** — same `HURL_VARIABLE_coolify_*` vars already in use                      |
| Existing `/prod-logs` command       | **Unchanged** — tool registration is additive, independent of command registration |

---

## Performance Profile

| Aspect                 | Characteristic                                                                                                              |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| **Runtime complexity** | O(n) for grep filtering (single pass over log lines), O(1) for tail slice, O(n) for truncation byte counting                |
| **Network**            | Single HTTP GET to Coolify API; no retries in tool handler                                                                  |
| **Memory**             | Log response held in memory as string array; typically < 1MB for a few thousand lines; truncation caps return value at 50KB |
| **Latency**            | Dominated by Coolify API response time (typically 1-5 seconds); local filtering negligible                                  |
| **Database**           | No database queries                                                                                                         |
| **State**              | Stateless — no caching, no persistence                                                                                      |
| **N+1 risk**           | None — single API call                                                                                                      |

---

## Cost Profile

No paid resources consumed. The Coolify API is self-hosted as part of the deployment infrastructure. No third-party API calls, no additional compute or storage.

---

## Production Infrastructure Steps

No production changes required:

- The `HURL_VARIABLE_coolify_*` environment variables are already configured in the pi runtime environment (the existing `/prod-logs` command already depends on them)
- No new environment variables, service provisioning, DNS changes, or firewall rules
- No database migrations
- No rollout/rollback steps (the change is a single TypeScript file; `/reload` applies it instantly)

---

## Documentation Updates

No project documentation files need updating:

- `docs/architecture.md` — already covers pi extensions generically; no new Elixir modules or architectural patterns introduced
- `docs/project-conventions.md` — no new conventions introduced
- `docs/production-infrastructure.md` — no infrastructure changes
- `docs/available-tasks.md` — no new mise tasks

The implementation is self-documenting: the tool's `description`, `promptSnippet`, and `promptGuidelines` tell the LLM when and how to use it.

---

## Dependencies

- `typebox` — already available as a pi built-in import (listed in pi extension docs under "Available Imports")
- `truncateTail`, `formatSize`, `DEFAULT_MAX_BYTES`, `DEFAULT_MAX_LINES` — all from `@mariozechner/pi-coding-agent`, a pi built-in
- No new npm dependencies needed

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Added `fetch_production_logs` tool to the existing `.pi/extensions/prod-logs/index.ts` extension. The tool reuses the existing `fetchLogs()` and `resolveVar()` helper functions. Implementation follows the plan exactly:

- Added imports for `Type` (typebox) and `truncateTail`, `formatSize`, `DEFAULT_MAX_BYTES`, `DEFAULT_MAX_LINES` (@mariozechner/pi-coding-agent)
- Registered tool before the existing `pi.registerCommand("prod-logs", ...)` call
- Tool supports `tail` (default 200) and `grep` parameters
- Handler: credential check → fetch → error handling → empty check → reverse → grep → tail → join → truncate → return
- Truncation via `truncateTail` with 50KB/2000-line limit, with clear truncation note in output
- Existing `/prod-logs` command code is completely untouched

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Added a `fetch_production_logs` tool to `.pi/extensions/prod-logs/index.ts` using `pi.registerTool()`. The tool gives the LLM programmatic access to production logs without user intervention.

**What changed:**

- Added imports for `Type` (typebox) and `truncateTail`, `formatSize`, `DEFAULT_MAX_BYTES`, `DEFAULT_MAX_LINES` from `@mariozechner/pi-coding-agent`
- Registered `fetch_production_logs` tool with `tail` (default 200) and `grep` parameters
- Tool reuses the existing `fetchLogs()` and `resolveVar()` module-scope functions from the `/prod-logs` extension
- Handler: credential validation → fetch → error handling → empty check → reverse (newest first) → grep filter → tail slice → join → `truncateTail` truncation with clear truncation note
- On missing credentials, returns a clear error listing which env vars are not set

**What didn't change:**

- The existing `/prod-logs` interactive command code is completely untouched
- No new dependencies, env vars, infrastructure changes, or Elixir module changes

**Verification (requires `/reload` in pi):**

1. Ask the LLM about available tools for production logs — should describe `fetch_production_logs`
2. Ask the LLM to fetch logs with `tail: 50` or `grep: "error"` — should work
3. Unset a credential and try — should get clear error message
4. Run `/prod-logs` — should still work unchanged

<!-- SECTION:FINAL_SUMMARY:END -->
