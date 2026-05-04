---
id: doc-6
title: 'Implementation Route Analysis: Programmatic Access to Production Logs'
type: other
created_date: '2026-05-04 06:43'
updated_date: '2026-05-04 06:45'
---
# Implementation Route Analysis: Programmatic Access to Production Logs

## Decision: Route B — Pi Tool via `pi.registerTool()` ✓ SELECTED

## Problem Statement

The `/prod-logs` pi extension (`.pi/extensions/prod-logs/index.ts`) provides an interactive TUI for viewing production logs from Coolify. The `fetchLogs()` function hits `{host}/api/v1/applications/{app_uuid}/logs` using a Bearer token. However, this is strictly user-interactive — the LLM cannot programmatically fetch logs.

The LLM needs a tool it can call to retrieve production logs directly into its context for analysis, debugging, and troubleshooting.

## Current Architecture Context

- **pi extensions** are TypeScript modules in `.pi/extensions/` that can register:
  - `pi.registerCommand()` — User-facing slash commands with interactive TUIs (what `/prod-logs` uses today)
  - `pi.registerTool()` — **Tools callable by the LLM during its agent loop** (same mechanism as `read`, `write`, `bash`, etc.)
- The existing `fetchLogs()` and `resolveVar()` are at module scope in the extension, so they're naturally shareable between the command handler and a new tool handler.
- **Tidewave MCP** provides Elixir-side tools via a separate MCP protocol channel.

---

## Route A: Tidewave MCP Tool (Elixir-side)

### Description
Add a new MCP tool `get_production_logs` to Tidewave that calls the Coolify API from Elixir using `Req`.

### Pros
- Architecturally consistent with existing MCP tools
- Req is battle-tested in this codebase
- Accessible by any MCP client

### Cons
- Must forward Coolify env vars to Phoenix app runtime
- Rewrites the API call in Elixir (no code reuse from existing `fetchLogs`)
- New Elixir module to maintain

### Verdict
**Rejected** in favor of Route B. The pi tool approach is simpler, reuses existing code and credentials directly, and keeps the change contained to a single file.

---

## Route B: Pi Tool via `pi.registerTool()` ✓ SELECTED

### Description
Add a `fetch_production_logs` tool registration to the existing `prod-logs` extension. The tool is called by the LLM directly (just like `read`, `bash`, etc.), fetches logs via the existing `fetchLogs()` function, and returns text content to the LLM.

### Pros
- **Direct code reuse**: Same `fetchLogs()` function, same `resolveVar()` helper, same env vars
- **No infrastructure changes**: No new Elixir modules, no credential forwarding, no config changes
- **First-class LLM tool**: The LLM calls it natively during its agent loop, the result flows through the same context pipeline as any other tool result
- **Minimal change**: ~50 lines added to the existing extension file
- **No external dependencies**: `typebox` is already available as a pi built-in import

### Cons
- pi-only (not accessible from other MCP clients — irrelevant for this use case)
- Tool definition consumes a small amount of LLM context window space (same as any tool)

### Architecture Impact
- **Modified file**: `.pi/extensions/prod-logs/index.ts` (add tool registration, ~50 lines)
- **No changes**: No Elixir modules, no config, no schemas, no routes, no UI

---

## Route C: Both — Deferred

Not needed. Route B satisfies the objective alone.
