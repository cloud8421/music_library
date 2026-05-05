---
id: doc-12
title: 'Research: Mute and Resolve Production Errors Implementation Routes'
type: specification
created_date: '2026-05-05 11:24'
---
# Research: Mute and Resolve Production Errors Implementation Routes

**Task:** ML-165 — Mute and resolve production errors from pi
**Date:** 2026-05-05

## Current State

### Backend (Elixir/Phoenix)

| Component | File | Status |
|---|---|---|
| Error schema | `deps/error_tracker/lib/error_tracker/schemas/error.ex` | Has `status` (:resolved/:unresolved) and `muted` (boolean) fields |
| Error context | `lib/music_library/errors.ex` | Read-only: `list_errors/1`, `get_error/1` — no update functions |
| Error controller | `lib/music_library_web/controllers/error_controller.ex` | `GET /api/v1/errors` (index), `GET /api/v1/errors/:id` (show) |
| Error JSON views | `lib/music_library_web/controllers/error_json.ex` | Renders error/occurrence data |
| Router | `lib/music_library_web/router.ex` | `/api/v1/errors` routes in API scope (Bearer token auth) |
| Auth | `lib/music_library_web/auth.ex` | `require_api_token/2` plug — Bearer token comparison |

### Pi Extension (TypeScript)

| Component | File | Status |
|---|---|---|
| prod-errors extension | `.pi/extensions/prod-errors/index.ts` | Tools: `fetch_production_errors`, `fetch_production_error`; Command: `/prod-errors` (TUI browser) |
| TUI ErrorBrowser | Same file, `ErrorBrowser` class | List view (no mute/resolve actions), Detail view (no mute/resolve actions) |

### Gap Analysis

1. **No mutation endpoints** — The API has no way to update an error's `muted` or `status` fields.
2. **No context functions** — `MusicLibrary.Errors` has no `mute_error/1` or `resolve_error/1` (or generic `update_error/2`).
3. **No pi tools** — No `mute_production_error` or `resolve_production_error` tool registered.
4. **No TUI actions** — The `/prod-errors` ErrorBrowser TUI has no keybindings to mute or resolve errors.

## Implementation Routes

### Route A: Dedicated POST Endpoints Per Action (Recommended)

Add two new routes, each handling a single action:

```
POST /api/v1/errors/:id/mute    → sets muted = true
POST /api/v1/errors/:id/resolve → sets status = :resolved
```

**Elixir changes:**
- `MusicLibrary.Errors`: Add `mute_error/1`, `resolve_error/1` (or a shared private helper)
- `MusicLibraryWeb.ErrorController`: Add `mute/2` and `resolve/2` actions
- `MusicLibraryWeb.ErrorJSON`: Add `mute/1`, `resolve/1` render functions
- `MusicLibraryWeb.Router`: Add two POST routes in the API scope

**Pi extension changes:**
- Register `mute_production_error` tool → POSTs to `/api/v1/errors/:id/mute`
- Register `resolve_production_error` tool → POSTs to `/api/v1/errors/:id/resolve`
- Add keybindings to `/prod-errors` TUI:
  - `M` (shift-m) in list view → mute selected error
  - `R` (shift-r) in detail view → resolve selected error
  - Or use single keys: `x` for mute, `d` for resolve (avoiding conflict with existing `m`/`r` filter toggles)

**Pros:**
- Simplest approach — each endpoint does exactly one thing
- RESTful resource/action pattern used elsewhere in the app (e.g., `/collection/latest`)
- Easy to extend with unmute/unresolve later as additional endpoints
- Clean tool-to-endpoint mapping in pi
- Easy to test independently

**Cons:**
- Two new routes instead of one
- If many more error actions are added, route count could grow

### Route B: Single PATCH Endpoint

Add one generic mutation endpoint:

```
PATCH /api/v1/errors/:id   body: {"muted": true} or {"status": "resolved"}
```

**Pros:**
- Single route for all error mutations
- Follows REST convention for partial updates
- Easily extensible to other fields

**Cons:**
- Parameter validation is more complex (must reject unknown fields, validate combinations)
- Tool semantics are less clear — the pi tool would need to construct the PATCH body
- PATCH semantics imply partial update; if both fields are sent, behavior must be defined
- Less explicit — the URL doesn't convey the action being performed
- Not aligned with existing project patterns (no other PATCH routes in the API)

### Route C: Single Action Endpoint

```
POST /api/v1/errors/:id/actions   body: {"action": "mute"} or {"action": "resolve"}
```

**Pros:**
- Single route for all actions
- Easy to add new action types
- Clean separation between action specification and execution
- Tool semantics map cleanly (tool name = action)

**Cons:**
- Less standard REST pattern
- Requires action validation/dispatch layer
- No existing precedent in the codebase

## Recommendation: Route A

Route A is the best fit for this project because:

1. **Convention alignment** — The project uses clear, descriptive route names for specific operations (e.g., `/collection/latest`, `/collection/random`, `/collection/on_this_day`). `POST /errors/:id/mute` and `POST /errors/:id/resolve` follow this pattern.

2. **Simplicity** — Each endpoint has a single responsibility. The controller actions, context functions, JSON views, and pi tools are all trivial to implement and test independently.

3. **Extensibility** — If unmute/unresolve are needed later, they can be added as `POST /errors/:id/unmute` and `POST /errors/:id/unresolve` without touching the existing endpoints.

4. **Pi tool mapping** — Each endpoint maps 1:1 to a pi tool (`mute_production_error` → `POST /errors/:id/mute`, `resolve_production_error` → `POST /errors/:id/resolve`). This makes the prompt guidelines simple and the tool behavior predictable.

5. **HTTP semantics** — POST is appropriate here because these are non-idempotent actions that change server state. POST on a sub-resource path is a well-established REST pattern.

## Architecture Impact

| Component | Impact |
|---|---|
| `MusicLibrary.Errors` | Add `mute_error/1`, `resolve_error/1` context functions |
| `MusicLibraryWeb.ErrorController` | Add `mute/2`, `resolve/2` actions |
| `MusicLibraryWeb.ErrorJSON` | Add render functions for success/error responses |
| `MusicLibraryWeb.Router` | Add two POST routes |
| `.pi/extensions/prod-errors/index.ts` | Add two tools, add TUI keybindings |
| `test/music_library_web/controllers/error_controller_test.exs` | Add tests for new endpoints |
| `test/music_library/errors_test.exs` | Add tests for new context functions (if separate test file exists) |
| `docs/architecture.md` | Update Routes section if it lists API routes |

No changes needed to: supervision tree, PubSub, schemas, migrations, Oban workers, LiveViews, external APIs.

## Performance Profile

- **Database**: Single-row UPDATE by primary key — O(1). SQLite handles this efficiently.
- **No N+1 risk**: These are simple UPDATE operations, no joins or preloads.
- **HTTP latency**: Sub-millisecond for the DB update + minimal JSON encoding.
- **Concurrency**: SQLite serializes writes — moot for low-frequency admin actions like mute/resolve.
- **No paid API calls** — these are entirely local operations.

## Cost Profile

Zero incremental cost. No external API calls, no additional compute, no additional storage.

## Production Infrastructure Steps

No production infrastructure changes needed. The new endpoints are served by the existing Phoenix app. No new environment variables, no DNS changes, no firewall rules.

## Documentation Updates

| File | Change |
|---|---|
| `docs/architecture.md` | Update Routes section if API routes are enumerated there |
| README (if applicable) | N/A — API is internal tooling |
| `.pi/extensions/prod-errors/index.ts` | Self-documenting through tool descriptions and prompt snippets |

## Testing

- **Controller tests**: Test auth (401 without token), test mute sets muted=true, test resolve sets status=resolved, test 404 for non-existent error, test idempotency (calling mute on already-muted error returns success with no change).
- **Context tests**: Test `mute_error/1` returns updated error, test `resolve_error/1` returns updated error, test error on non-existent ID.
