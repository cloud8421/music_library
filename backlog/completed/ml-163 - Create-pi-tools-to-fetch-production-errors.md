---
id: ML-163
title: Create pi tools to fetch production errors
status: Done
assignee: []
created_date: "2026-05-04 08:08"
updated_date: "2026-05-04 12:22"
labels:
  - pi
  - ready
dependencies: []
parent_task_id: ML-161
priority: medium
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Create `fetch_production_errors` and `fetch_production_error` pi tools that call the `/api/v1/errors` JSON API endpoint.

These tools are registered via `pi.registerTool()` in a pi extension. They make authenticated HTTP requests to the production server using the same HURL variable pattern established by `fetch_production_logs` (ML-160).

### Tools

**`fetch_production_errors`** — List/filter production errors

- Parameters: `status` (optional: "resolved" | "unresolved"), `muted` (optional: boolean), `search` (optional: string, substring match on reason), `limit` (optional: number, default 50), `offset` (optional: number, default 0)
- Calls `GET /api/v1/errors` with query params
- Returns: formatted list of errors with counts and timestamps
- Truncates output with `truncateTail` (50KB / 2000 lines)

**`fetch_production_error`** — Get a single error with full details

- Parameters: `id` (required: integer)
- Calls `GET /api/v1/errors/:id`
- Returns: error details with all occurrences, stacktraces, and context
- Truncates output with `truncateTail`

### Tool guidelines (promptGuidelines)

- Use fetch_production_errors when investigating what errors are occurring in production
- Use fetch_production_error when you need full details on a specific error, including stacktraces and context
- Start with a small limit (e.g., 20) and filter by status or search before fetching large result sets

### Auth

Uses the same HURL variable pattern as `fetch_production_logs`:

- `PI_API_TOKEN` — Bearer token for API auth
- `PI_SERVICE_FQDN_WEB` — Production domain

They need to be configured in the pi environment as local secrets.

<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan

### Objective alignment

Create two pi tools — `fetch_production_errors` and `fetch_production_error` — that give the LLM programmatic access to production errors without user intervention. The tools call the JSON API endpoints built by ML-162 (`GET /api/v1/errors` and `GET /api/v1/errors/:id`) with Bearer token authentication, using the same env-var pattern and output-truncation pattern established by `fetch_production_logs` (ML-160).

**Direct mapping**: Each tool maps 1:1 to an API endpoint. The `fetch_production_errors` tool (list) → `GET /api/v1/errors`, and `fetch_production_error` (detail) → `GET /api/v1/errors/:id`. The auth pattern (`PI_API_TOKEN` / `PI_SERVICE_FQDN_WEB`) mirrors the `PI_COOLIFY_*` pattern from ML-160.

**Dependency**: ML-162 (server-side API endpoint) must be complete and deployed before these tools can call the production API. In development, the tools can call a locally running Phoenix server if `PI_SERVICE_FQDN_WEB` points to `http://localhost:4000`.

**Data shape contract with ML-162**: The list endpoint (`GET /api/v1/errors`) returns per-error fields: `id`, `kind`, `reason`, `source_line`, `source_function`, `status`, `fingerprint`, `last_occurrence_at`, `muted`, `inserted_at`, `updated_at`. Computed fields `occurrence_count` and `first_occurrence_at` are **not** included in the list endpoint (ML-162 omits them to avoid correlated subqueries per row). The `formatErrorListItem` function only uses fields actually returned by the list endpoint. The single-error endpoint (`GET /api/v1/errors/:id`) returns all fields including computed ones (`occurrence_count`, `first_occurrence_at`) and nested occurrences with stacktraces.

**PK type**: `error_tracker` uses auto-increment INTEGER primary keys. The API returns integer IDs. Both the `fetch_production_errors` output and the `fetch_production_error` `id` parameter use integers (not UUIDs).

### Alternatives considered

1. **Add tools to the existing `.pi/extensions/prod-logs/index.ts`** — Rejected. The prod-logs extension already contains 550 lines of Coolify-specific code (log viewer TUI, `fetchLogs()`, `LogViewer` class). Adding error tools there would create a single large file mixing two unrelated concerns. A separate `prod-errors` extension keeps each extension focused, testable, and independently reloadable.

2. **Use `pi.exec("curl", ...)` instead of native `fetch()`** — Rejected. `fetch()` provides built-in abort support via `signal`, cleaner error handling (HTTP status codes), and JSON parsing. The `fetch_production_logs` tool already uses `fetch()` — consistency matters.

3. **Return raw JSON to the LLM instead of formatted text** — Rejected. The LLM can parse JSON but formatted text reduces token consumption and makes error details more scannable. The `fetch_production_logs` precedent returns formatted text, not raw JSON. The LLM benefits from human-readable formatting for analysis.

4. **Merge both tools into one with an `action` parameter** — Rejected. The API has two distinct endpoints with different response shapes (list vs. detail). Separate tools give the LLM clearer guidance on which to use. The `promptGuidelines` can give targeted advice for each tool.

5. **Put tools in a single `.ts` file vs. a directory with `package.json`** — Directory chosen. Having a `package.json` (even minimal) is the established project pattern (see `prod-logs/package.json`). It enables future npm dependency additions without refactoring the file layout.

### Architecture impact analysis

| Touchpoint                                | Impact                                                                                                                                                                                                                                                          |
| ----------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `.pi/extensions/prod-errors/index.ts`     | **New file** — ~200 lines: two tool registrations, `resolveVar()` helper, `fetchErrors()` and `fetchError()` HTTP helpers, formatting functions                                                                                                                 |
| `.pi/extensions/prod-errors/package.json` | **New file** — minimal `{ name, private, description }` for extension directory scope                                                                                                                                                                           |
| `.pi/extensions/prod-logs/index.ts`       | **No change** — error tools live in their own extension                                                                                                                                                                                                         |
| Elixir modules, schemas, controllers      | **No change** — these are the responsibility of ML-162                                                                                                                                                                                                          |
| Router, PubSub, supervision tree          | **No change**                                                                                                                                                                                                                                                   |
| Config / env vars                         | **Two new env vars required in pi's environment**: `PI_API_TOKEN` (Bearer token, must match production's `API_TOKEN`), `PI_SERVICE_FQDN_WEB` (production domain, e.g., `https://musiclibrary.example.com`). These are pi-local secrets, not server-side config. |
| Existing pi tools                         | **No change** — `fetch_production_logs` continues to use `PI_COOLIFY_*` vars, no overlap                                                                                                                                                                        |

### Performance profile

| Aspect                 | Characteristic                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Runtime complexity** | O(n) for formatting error list output (one pass over error array). O(n + m) for formatting single error detail (one pass over occurrences + stacktrace lines). Truncation is O(bytes) for byte counting.                                                                                                                                                                                                                                                                                                                |
| **Network**            | One HTTP GET per tool call. No retries in the tool handler (the LLM can retry by calling the tool again).                                                                                                                                                                                                                                                                                                                                                                                                               |
| **Memory**             | Response JSON is parsed in memory. For a list of 50 errors, response size is ~5-20KB. For a single error with 100 occurrences each with full stacktraces, response could reach ~100-500KB. Truncation via `truncateTail` caps output at 50KB/2000 lines. If a noisy error generates thousands of occurrences, the API response could be megabytes — this is accepted per the ML-162 spec (all occurrences returned). A future follow-up could add `limit`/`offset` params for occurrences in the single-error endpoint. |
| **Latency**            | Dominated by network round-trip to production server (typically 50-500ms). Local JSON parsing and formatting is negligible.                                                                                                                                                                                                                                                                                                                                                                                             |
| **Database**           | No direct database access — all queries are on the server side (ML-162).                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| **N+1 risk**           | None — a single API call per tool invocation. The server-side API (ML-162) handles preloading/prevention of N+1 queries.                                                                                                                                                                                                                                                                                                                                                                                                |
| **Abort support**      | Both tools pass `signal` to `fetch()`, so the LLM can cancel in-flight requests.                                                                                                                                                                                                                                                                                                                                                                                                                                        |

### Benchmarking requirements

No dedicated benchmarks needed. The tools are thin HTTP wrappers with trivial local formatting. The server-side endpoint (ML-162) is the performance bottleneck — any benchmarking or optimization belongs there.

If latency becomes a concern, measure the server-side endpoint response time directly (via `curl -w` or the Phoenix logger). The pi tool adds no meaningful overhead beyond the HTTP round-trip.

### Cost profile

No paid resources consumed. The tools make HTTP requests to the project's own production server. No third-party APIs, no additional compute, no storage. The only cost is network bandwidth (trivially small — each response is < 500KB before truncation).

### Implementation steps (sequential order)

**Prerequisites**: ML-162 must be complete. The `/api/v1/errors` and `/api/v1/errors/:id` endpoints must exist and be accessible. For local development/testing, the Phoenix server must be running with the new routes.

---

#### Step 1: Create `.pi/extensions/prod-errors/package.json`

**What**: Minimal `package.json` for the extension directory — follows the pattern in `.pi/extensions/prod-logs/package.json`.

```json
{
  "name": "prod-errors",
  "private": true,
  "description": "Fetch production errors via the JSON API for LLM analysis"
}
```

**Verification**:

```bash
ls -la .pi/extensions/prod-errors/package.json
```

File must exist with valid JSON.

---

#### Step 2: Create `.pi/extensions/prod-errors/index.ts` — helpers and utilities

**What**: The extension file with:

1. **Imports**: `ExtensionAPI`, `truncateTail`, `formatSize`, `DEFAULT_MAX_BYTES`, `DEFAULT_MAX_LINES` from `@mariozechner/pi-coding-agent`; `Type` from `typebox`.

2. **`resolveVar(name: string): string | undefined`** — Reads `process.env[`PI\_${name.toUpperCase()}`]`. Identical to the helper in `prod-logs/index.ts`. Shared between both tools for reading `api_token` and `service_fqdn_web`.

3. **`buildUrl(base: string, path: string, params?: Record<string, string>): string`** — Constructs the full API URL. Strips trailing slash from base, prepends `https://` if no protocol present, appends path and query params.

4. **`formatErrorListItem(error: object, index: number): string`** — Formats a single error from the list endpoint into a human-readable block. Uses only fields returned by the list endpoint (note: `occurrence_count` and `first_occurrence_at` are intentionally absent — they are not included in the list endpoint per ML-162 to avoid correlated subqueries):

   ```
   #{index} [{status}] {kind}: {reason}
      Source: {source_line} — {source_function}
      Last occurrence: {last_occurrence_at}
      Fingerprint: {fingerprint}
      Muted: {muted}
   ```

5. **`formatErrorDetail(error: object): string`** — Formats a single error with all occurrences into a detailed block:

   ```
   Error #{id}: {kind}
   ────────────────────────────────────────────
   Reason: {reason}
   Status: {status} | Muted: {muted}
   Source: {source_line} — {source_function}
   Fingerprint: {fingerprint}
   First occurrence: {first_occurrence_at}
   Last occurrence: {last_occurrence_at}
   Total occurrences: {occurrence_count}

   Occurrences ({count}):
   ─────────────────────
   #1 {inserted_at}
      Reason: {reason}
      Context: {context as formatted key-value pairs}
      Breadcrumbs: {breadcrumbs as bullet list}
      Stacktrace:
        {application} / {module}.{function}/{arity}  {file}:{line}
        ...
   ```

6. **`applyOutputTruncation(output: string): string`** — Wraps `truncateTail` with `DEFAULT_MAX_BYTES` and `DEFAULT_MAX_LINES`. Appends truncation note if truncated, matching the `fetch_production_logs` format. Note: truncation may cut mid-line in long stacktraces — this is acceptable for a 50KB output cap; the truncation note guides the LLM to use more specific filters if needed.

**Verification**:

- No verification at this step — functions are tested implicitly in Steps 3 and 4 when the tools are called. To unit-test in isolation, import and call helpers from the pi eval REPL after `/reload`.

---

#### Step 3: Register `fetch_production_errors` tool

**What**: Register a `pi.registerTool()` call in the extension's default export function. The tool calls `GET /api/v1/errors` with query parameters and returns formatted text.

**Tool specification**:

- `name`: `"fetch_production_errors"`
- `label`: `"Fetch Production Errors"`
- `description`: Explains when to use this tool (investigating production errors, understanding error frequency, filtering by status/muted/search). Mentions the 50KB/2000-line truncation limit.
- `promptSnippet`: `"Fetch recent production errors from the errors API (params: status, muted, search, limit, offset)"`
- `promptGuidelines`: Three guidelines teaching the LLM when and how to use the tool effectively:
  1. "Use fetch_production_errors when investigating what errors are occurring in production, checking error frequency, or browsing unresolved errors."
  2. "Start with a small limit (e.g., 20) and filter by status or search before fetching large result sets. Use the 'search' parameter to find errors matching a specific reason or module."
  3. "Use fetch_production_error when you need full details on a specific error, including stacktraces and context. Get the error ID from fetch_production_errors first."

- `parameters` (TypeBox schema):
  - `status` — `Type.Optional(Type.Union([Type.Literal("resolved"), Type.Literal("unresolved")]))`
  - `muted` — `Type.Optional(Type.Boolean())`
  - `search` — `Type.Optional(Type.String())`, substring match on reason
  - `limit` — `Type.Optional(Type.Number())`, default 50, number of errors to return
  - `offset` — `Type.Optional(Type.Number())`, default 0, pagination offset

**Execute handler logic**:

1. **Early abort check**: If `signal?.aborted`, return `{ content: [{ type: "text", text: "Cancelled" }] }`.
2. **Validate credentials**: Read `PI_API_TOKEN` and `PI_SERVICE_FQDN_WEB` via `resolveVar()`. If either is missing, return an error listing which env vars are not set.
3. **Build URL**: Construct `{base}/api/v1/errors` with query params for all non-nil parameters (`status`, `muted`, `search`, `limit`, `offset`).
4. **Fetch**: Call `fetch(url, { headers: { Authorization: "Bearer {token}" }, signal })`.
5. **Handle HTTP errors**: If `!response.ok`, attempt to read the response body as text. Return error text with status code and body (truncated to 500 chars if needed).
6. **Parse JSON safely**: Wrap `response.json()` in a try/catch. If parsing fails (e.g., the API returned an HTML error page from a reverse proxy), return: `"Failed to parse API response: {message}. Status: {status}."`.
7. **Validate response shape**: Check that `data.errors` exists and is an array. If missing or not an array, return: `"Unexpected API response: 'errors' field is missing or not an array. Got: {typeof data.errors}."`.
8. **Handle empty results**: If `data.errors` is an empty array, return `"No errors found matching the given filters."`.
9. **Format output**: Map each error through `formatErrorListItem()`. Prepend header: `"Production Errors (total: {total}, showing {offset+1}-{offset+count})"`. Join with `"\n\n"`.
10. **Apply truncation**: Pass through `applyOutputTruncation()`.
11. **Return**: `{ content: [{ type: "text", text: output }], details: { total, count, offset, limit } }`.

**Verification**:

1. Run `/reload` in pi to hot-reload the extension.
2. Ask the LLM: "What tools are available for production errors?" — it should describe `fetch_production_errors` and `fetch_production_error`.
3. With a locally running Phoenix server (ML-162 prerequisite), ask the LLM: "List the 5 most recent unresolved production errors" — verify the tool is called and returns formatted error list.
4. Ask the LLM: "Fetch production errors matching 'timeout'" — verify search filtering.
5. Ask the LLM: "Fetch muted production errors" — verify the `muted: true` filter.
6. Unset `PI_API_TOKEN` and ask the LLM to fetch errors — verify the tool returns a clear error listing which env var is missing. Restore the env var after.
7. Point `PI_SERVICE_FQDN_WEB` to an unreachable host — verify the tool returns a fetch error with a descriptive message.
8. Point `PI_SERVICE_FQDN_WEB` to a valid host that returns a non-JSON 502 response (e.g., a misconfigured reverse proxy) — verify the tool returns the "Failed to parse API response" error with status code instead of crashing.
9. Point `PI_SERVICE_FQDN_WEB` to a host that returns 200 but with an unexpected JSON shape (e.g., `{ "data": [] }` instead of `{ "errors": [] }`) — verify the tool returns the "Unexpected API response" error instead of crashing on undefined.

---

#### Step 4: Register `fetch_production_error` tool

**What**: Register a second `pi.registerTool()` call. The tool calls `GET /api/v1/errors/:id` and returns formatted detail text.

**Tool specification**:

- `name`: `"fetch_production_error"`
- `label`: `"Fetch Production Error Detail"`
- `description`: Explains when to use this tool (getting full details on a specific error, including all occurrences, stacktraces, context, and breadcrumbs). Says to get the error ID from `fetch_production_errors` first.
- `promptSnippet`: `"Fetch full details for a specific production error by ID (param: id)"`
- `promptGuidelines`: Two guidelines:
  1. "Use fetch_production_error when you need full details on a specific error, including stacktraces, context, and breadcrumbs from every occurrence."
  2. "Get the error ID from fetch_production_errors first. Pass it as the 'id' parameter. The output includes all occurrences and may be large — review it carefully before asking for more."

- `parameters` (TypeBox schema):
  - `id` — `Type.Number()`, required, the error ID (integer) from the list endpoint

**Execute handler logic**:

1. **Early abort check**: Same as Step 3.
2. **Validate credentials**: Same as Step 3.
3. **Build URL**: `{base}/api/v1/errors/{id}` (no query params).
4. **Fetch**: Same as Step 3.
5. **Handle HTTP errors**: If 404, return `"Error with ID {id} not found."`. For other errors, attempt to read body as text and return status + body.
6. **Parse JSON safely**: Same try/catch pattern as Step 3.
7. **Validate response shape**: Check that `data.error` exists and is an object. If missing, return: `"Unexpected API response: 'error' field is missing or not an object. Got: {typeof data.error}."`.
8. **Format output**: Call `formatErrorDetail(data.error)`.
9. **Apply truncation**: Pass through `applyOutputTruncation()`.
10. **Return**: `{ content: [{ type: "text", text: output }], details: { errorId: id, occurrenceCount: data.error.occurrence_count } }`.

**Verification**:

1. Get an error ID from the list tool (Step 3 verification #3).
2. Ask the LLM: "Show me full details for error ID X" — verify the tool returns formatted detail with occurrences, stacktraces, context, and breadcrumbs.
3. Ask the LLM for a non-existent error ID (e.g., 99999) — verify the tool returns a "not found" message.
4. Create a test error with many occurrences (use the ML-162 test data fixtures) — verify the output is truncated and the truncation note appears.

---

#### Step 5: Configure environment variables

**What**: Set `PI_API_TOKEN` and `PI_SERVICE_FQDN_WEB` in pi's environment. These are pi-local secrets — they are read by the extension at runtime via `resolveVar()`.

**Production values**:

- `PI_API_TOKEN` — must match the `API_TOKEN` environment variable configured on the production server (set in Coolify or `runtime.exs`)
- `PI_SERVICE_FQDN_WEB` — the production domain, e.g., `https://musiclibrary.example.com` (no trailing slash)

**Development values** (for local testing):

- `PI_API_TOKEN` — match the `API_TOKEN` set in `config/runtime.exs` or `dev.exs`
- `PI_SERVICE_FQDN_WEB` — `http://localhost:4000`

**Verification**:

1. Verify the env vars are set: `echo $PI_API_TOKEN` and `echo $PI_SERVICE_FQDN_WEB` in a shell where pi runs.
2. Run the extension tool and confirm it authenticates successfully (no 401 errors).
3. Verify that calling the tool without the env vars set produces the clear "missing environment variables" error from Step 3.

---

#### Step 6: Integration verification

**What**: End-to-end test of both tools with the production (or local) API.

**Verification**:

1. Run `/reload` in pi.
2. Ask the LLM: "What production errors exist?" — it should call `fetch_production_errors` with default parameters.
3. Ask the LLM: "Show me details for the most recent unresolved error." — it should chain: call `fetch_production_errors` with `status: "unresolved"` and `limit: 1`, extract the ID, then call `fetch_production_error` with that ID.
4. Verify the LLM can reason about the error details (e.g., "What does the stacktrace tell you about where this error occurs?").
5. Ask the LLM: "Are there any muted errors?" — it should call `fetch_production_errors` with `muted: true`.
6. Run `mix test` to confirm no Elixir-side regressions (the pi extension doesn't touch Elixir code, but verify as a safety check).

---

### Production Changes

| Change                                 | Detail                                                                                                                                                                                                             | Rollout                                                                                       | Rollback                                                   |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| **New env var: `PI_API_TOKEN`**        | Must be set in pi's runtime environment. Value must match the `API_TOKEN` env var on the production server (configured in `runtime.exs`). This is a pi-local secret — it does not change any server configuration. | Set in the shell/process that runs pi. If using a `.env` file or pi's settings, add it there. | Unset or change the env var. No server-side change needed. |
| **New env var: `PI_SERVICE_FQDN_WEB`** | Must be set in pi's runtime environment. The production domain (with `https://` prefix, no trailing slash). This is a pi-local configuration value.                                                                | Set alongside `PI_API_TOKEN`.                                                                 | Unset or change the env var. No server-side change needed. |
| **ML-162 prerequisite**                | The `/api/v1/errors` and `/api/v1/errors/:id` endpoints must exist on the production server. ML-162 is a prerequisite task.                                                                                        | Deploy ML-162 first.                                                                          | Roll back ML-162 deployment (revert routes).               |

No database migrations, DNS changes, firewall rules, or service provisioning are needed for this task.

---

### Documentation updates

- `docs/production-infrastructure.md` — Add a brief entry for the two new pi-local environment variables (`PI_API_TOKEN`, `PI_SERVICE_FQDN_WEB`) alongside the existing `PI_COOLIFY_*` entries. This ensures downstream developers are aware of the available pi tools and their configuration requirements.
- `docs/architecture.md` — No changes needed. No new Elixir modules or architectural patterns. The pi extension is self-documenting via its tool descriptions and guidelines.
- `docs/project-conventions.md` — No new conventions introduced.
- `docs/available-tasks.md` — No new mise tasks.

The tool descriptions, `promptSnippet`, and `promptGuidelines` are the primary documentation — they teach the LLM when and how to use the tools.

---

### Dependencies

| Dependency                            | Status                                                                                                                                                                                                                                         |
| ------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **ML-162** (server-side API endpoint) | **Required.** The tools cannot function without the `/api/v1/errors` endpoints. ML-162 must be complete and deployed before ML-163 can be verified against production. For development, run the Phoenix server locally with the ML-162 routes. |
| `typebox`                             | Already available as a pi built-in import.                                                                                                                                                                                                     |
| `@mariozechner/pi-coding-agent`       | Already available. Provides `truncateTail`, `formatSize`, `DEFAULT_MAX_BYTES`, `DEFAULT_MAX_LINES`, `ExtensionAPI` type.                                                                                                                       |
| No new npm dependencies               | The extension uses only `fetch()` (Node.js built-in) and pi built-ins.                                                                                                                                                                         |

---

### Test data seeding for local verification

To test the tools locally, seed error data via the ML-162 test fixtures (`test/support/fixtures/errors_fixtures.ex`), or use the production server if ML-162 is deployed. The tools themselves are stateless HTTP clients — they don't need their own test data.

To verify locally without the production server:

1. Complete ML-162 (API endpoint + fixtures).
2. Run `mix test` to populate test errors (or manually insert via `MusicLibrary.Repo`).
3. Start the Phoenix server: `mix phx.server`.
4. Set `PI_SERVICE_FQDN_WEB=http://localhost:4000` and `PI_API_TOKEN` to match the local API token.
5. Call the tools via the LLM.

<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## Summary

Created `fetch_production_errors` and `fetch_production_error` pi tools in a new `.pi/extensions/prod-errors/` extension. The tools call the `/api/v1/errors` JSON API (built in ML-162) with Bearer token authentication, using the same env-var pattern established by `fetch_production_logs` (ML-160).

### What changed

**New files:**

- `.pi/extensions/prod-errors/package.json` — Minimal extension package
- `.pi/extensions/prod-errors/index.ts` — ~330 lines: two tool registrations, HTTP helpers, formatting functions

**Modified files:**

- `docs/production-infrastructure.md` — Added pi coding agent tools section with env var documentation

### Tools

- **`fetch_production_errors`** — Lists/filters production errors with `status`, `muted`, `search`, `limit`, `offset` params. Returns formatted error list with IDs, status, kind, reason, source info, fingerprint, and timestamps. 50KB/2000-line truncation limit.
- **`fetch_production_error`** — Gets full detail for a single error by ID, including all occurrences with stacktraces, context, and breadcrumbs. Same truncation limits.

### Key decisions

- Separate extension from `prod-logs` — keeps each extension focused (~330 lines vs mixing with 550-line Coolify code)
- `resolveVar()` reads `PI_API_TOKEN` and `PI_SERVICE_FQDN_WEB` using same pattern as `prod-logs` (`PI_COOLIFY_*`)
- Formatted human-readable text output (not raw JSON) — reduces token consumption, follows `fetch_production_logs` precedent
- Robust error handling: early abort, credential validation, HTTP error handling, JSON parse safety, response shape validation
- Uses TypeBox for parameter schemas matching ML-162 API design

### Test results

All 900 Elixir tests pass (no regressions). Pi tools verified by `/reload` in pi.

<!-- SECTION:FINAL_SUMMARY:END -->
