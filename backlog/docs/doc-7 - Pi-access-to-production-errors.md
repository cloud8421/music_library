---
id: doc-7
title: Pi access to production errors
type: other
created_date: "2026-05-04 08:07"
updated_date: "2026-05-04 08:13"
---

# Implementation Routes: pi access to production errors

## Problem

The project captures production errors via the `error_tracker` Elixir dependency (stored in `MusicLibrary.TelemetryRepo` SQLite database). Errors can currently only be viewed through the built-in web dashboard at `/dev/errors` (behind login auth, only with `:monitoring_routes` enabled). There is no programmatic access — no API, no tooling, no pi extension.

The goal is to enable pi (the coding agent) to fetch and browse production errors. This requires three layers:

1. A programmatic API to expose error data (behind auth)
2. Pi tools the LLM can call to fetch errors
3. A pi extension for interactive browsing

## Routes Evaluated

### Route A: JSON API endpoint on Phoenix (RECOMMENDED)

**How it works:**
Add a new API controller (`MusicLibraryWeb.ErrorsController`) with two endpoints under `/api/v1/errors`:

- `GET /api/v1/errors` — list errors with optional filtering (status, muted, search) and pagination
- `GET /api/v1/errors/:id` — single error detail with its occurrences and stacktraces

The controller queries the `error_tracker_errors` and `error_tracker_occurrences` tables via Ecto. Auth is handled by the existing `require_api_token` plug (Bearer token), which is already used by the `/api/v1` pipeline.

Pi tools (`fetch_production_errors` and `fetch_production_error`) make HTTP requests to this API using `fetch()` or `pi.exec("curl", ...)`. The pi extension builds on these tools for an interactive TUI.

**Pros:**

- Follows existing patterns exactly (see `CollectionController`, `require_api_token`)
- Clean separation of concerns: API layer, tool layer, extension layer
- Pi tools work remotely — no need for SSH or filesystem access to the production server
- Can be tested independently at each layer
- Auth is handled at the plug level, no new auth infrastructure needed
- API can be reused by other consumers (scripts, monitoring, future tooling)
- CORS not needed (pi tools call from the same origin or via CLI)
- The TelemetryRepo already exists and has the tables — no new database work

**Cons:**

- Requires a server code change and deployment
- Adds two new routes

**Changes needed:**
| Layer | Change |
|-------|--------|
| Server | New `ErrorsController` + `ErrorJSON` view or serializer |
| Server | 2 new routes in `router.ex` under `/api/v1` scope |
| Server | New context module (or inline queries) for error_tracker data |
| Pi | New tool registrations in a pi extension |
| Pi | Optional TUI extension for browsing |

---

### Route B: Direct SQLite access from pi tools

**How it works:**
Pi tools execute SQL queries directly against the TelemetryRepo SQLite database file. In development this is trivial (local file). In production, the pi session would need SSH access to the production server, or the SQLite file would need to be synced locally (e.g., via `mise run prod:backup`).

No server-side API changes needed. The pi tools would use `pi.exec("sqlite3", ...)` or read the database file directly.

**Pros:**

- Zero server code changes
- Immediate access to ALL data — no API shape limitations
- Can run complex ad-hoc queries without API changes

**Cons:**

- **Production access requires SSH or filesystem access** — violates the project's existing API-based pattern for pi access (cf. `fetch_production_logs` which uses Coolify API, not SSH)
- No auth layer — tools have full read access to the entire database
- Tightly couples pi tools to the error_tracker schema — any migration could break tools
- No API reuse — cannot be consumed by other clients
- Each pi tool call requires a separate SQLite process (or a WS/SSE connection to keep a persistent session)
- Production SQLite is under concurrent write load from the app and Litestream — reading directly could impact performance
- Production database file may be locked or busy

**Verdict: Rejected.**
The direct-access approach introduces deployment friction (SSH key management, filesystem access) that contradicts existing patterns. The app already has an authenticated API pipeline — extending it is simpler and safer.

---

### Route C: Tidewave MCP / existing pi infrastructure only

**How it works:**
Use the existing Tidewave MCP tools (`tidewave_execute_sql_query`) to query the error_tracker tables directly. This is available in dev but would need the Tidewave MCP server to be accessible in production (e.g., via SSH tunnel or a production-side MCP server).

**Pros:**

- No new code at all — uses what's already there
- `tidewave_execute_sql_query` already understands the repo structure

**Cons:**

- **Tidewave MCP server does not run in production** — it's a development-only tool
- Even if it did, running a dev tool against production is architecturally wrong
- No browsing UX, no filtering, no pagination — basic SQL results only
- Auth is missing — would need a separate mechanism

**Verdict: Rejected.**
Tidewave is a development tool. Exposing it to production would be an architectural antipattern and a security concern.

---

### Route D: Expose via Coolify API (like production logs)

**How it works:**
Add an endpoint to the existing Coolify-like API pattern used by `fetch_production_logs`. This would require Coolify to expose error_tracker data, which it doesn't natively support. Could potentially parse production logs for error patterns, but that's unstructured and duplicative.

**Pros:**

- Consistent with the existing `fetch_production_logs` pattern

**Cons:**

- Coolify doesn't expose error_tracker data
- ErrorTracker already has structured data — parsing it from raw logs is backwards and lossy
- Would require Coolify API changes or custom Coolify plugin

**Verdict: Rejected.**
Coolify is the wrong layer for structured error data. ErrorTracker already stores structured errors — adding Coolify as an intermediary adds complexity without benefit.

---

## Recommendation

**Route A: JSON API on Phoenix** is the clear winner. It:

1. **Follows existing patterns** — the project already has an authenticated API pipeline with Bearer tokens (see `CollectionController`, `require_api_token`)
2. **Has precedent** — `fetch_production_logs` (ML-160) established the pattern of pi tools calling an authenticated API
3. **Is testable** — each layer (API, tool, extension) can be tested independently
4. **Is reusable** — the API can serve other consumers beyond pi
5. **Has minimal production impact** — new controller + routes, no infrastructure changes
6. **Respects auth boundaries** — the existing `require_api_token` plug handles authentication

### Architecture

```
┌─────────────────────────────────────────────────┐
│                   pi session                      │
│                                                   │
│  ┌──────────────┐  ┌──────────────────────────┐  │
│  │ pi extension  │  │  pi tools                │  │
│  │ (TUI browse)  │──│  fetch_production_errors  │  │
│  │               │  │  fetch_production_error   │  │
│  └──────────────┘  └──────────┬───────────────┘  │
└───────────────────────────────┼───────────────────┘
                                │ HTTP (Bearer token)
                                ▼
┌───────────────────────────────┼───────────────────┐
│                 Phoenix Server                     │
│                                                   │
│  GET/POST /api/v1/errors ───► ErrorsController    │
│  GET /api/v1/errors/:id ───► ErrorsController     │
│                                    │              │
│                                    ▼              │
│                          TelemetryRepo (SQLite)    │
│                          error_tracker_errors      │
│                          error_tracker_occurrences │
└───────────────────────────────────────────────────┘
```

### Subtask breakdown

1. **ML-161: Expose production errors via JSON API** — Server-side: controller, routes, JSON views, context queries
2. **ML-162: Create pi tools to fetch errors** — Pi extension: `fetch_production_errors` and `fetch_production_error` tools via `pi.registerTool()`
3. **ML-163: Create pi extension for error browsing** — Pi extension: interactive TUI for browsing errors via `ctx.ui.custom()`
