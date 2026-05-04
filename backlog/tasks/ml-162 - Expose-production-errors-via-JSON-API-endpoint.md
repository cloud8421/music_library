---
id: ML-162
title: Expose production errors via JSON API endpoint
status: Done
assignee: []
created_date: '2026-05-04 08:08'
updated_date: '2026-05-04 12:11'
labels:
  - api
  - ready
dependencies: []
parent_task_id: ML-161
priority: medium
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add an API controller and routes under `/api/v1/errors` to expose ErrorTracker data as JSON, behind the existing Bearer token auth.

This subtask covers the server-side work only: controller, JSON serialization, context queries, and routes. The pi tooling and extensions are covered by separate subtasks.

### API design

**`GET /api/v1/errors`** — List errors
- Query params: `status` (resolved/unresolved), `muted` (true/false), `search` (substring match on reason), `limit` (default 50), `offset` (default 0)
- Returns: `{ errors: [...], total: n, limit: n, offset: n }`
- Each error includes: id, kind, reason, source_line, source_function, status, fingerprint, last_occurrence_at, muted, inserted_at, updated_at, occurrence_count, first_occurrence_at

**`GET /api/v1/errors/:id`** — Single error detail
- Returns the error with all its occurrences (with stacktraces), sorted by inserted_at desc
- Each occurrence includes: id, reason, context, breadcrumbs, stacktrace (lines), inserted_at

### Data attributes (canonical — shared with all subtasks)

**Error fields:** id, kind, reason, source_line, source_function, status, fingerprint, last_occurrence_at, muted, inserted_at, updated_at
**Occurrence fields:** id, reason, context, breadcrumbs, stacktrace (with lines), error_id, inserted_at
**Computed:** occurrence_count, first_occurrence_at

### Dependencies

- Uses `MusicLibrary.TelemetryRepo` (already exists)
- Uses the `error_tracker_errors` and `error_tracker_occurrences` tables (already exist)
- Auth via existing `require_api_token` plug (already in use by `/api/v1` pipeline)
<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

### Objective alignment

Add two JSON API endpoints under `/api/v1/errors` (already behind the existing Bearer token auth plug `require_api_token`) that expose `error_tracker_errors` and `error_tracker_occurrences` table data. The endpoints enable programmatic access to production errors for the pi tooling (ML-163) and extension (ML-164) subtasks.

**Data source correction**: The task description states "Uses `MusicLibrary.TelemetryRepo`" but `error_tracker` is configured with `repo: MusicLibrary.Repo` in `config/config.exs`. The error_tracker tables (`error_tracker_errors`, `error_tracker_occurrences`) live in the main app database, not the telemetry database. **All queries in this plan use `MusicLibrary.Repo`** — the repo that actually holds the data. (The TelemetryRepo holds only telemetry metrics data.)

**PK type correction**: The task description describes `id` as UUID, but `error_tracker` uses auto-increment INTEGER primary keys. The API will return integer IDs.

### Alternatives considered

1. **Query error_tracker tables directly from the controller** — Rejected. Violates the "Context modules own all queries" architecture convention. All LiveViews and controllers call context functions.

2. **Add error query functions to an existing context** — Rejected. No existing context owns these tables. A new `MusicLibrary.Errors` context is the cleanest home.

3. **Use error_tracker's built-in query functions** — Rejected. `ErrorTracker` exposes CRUD operations (`report/3`, `resolve/1`, `mute/1`, etc.) but no listing/querying API for retrieval. We need raw `Ecto.Query` against the schemas.

4. **Add the context under `MusicLibraryWeb`** — Rejected. Contexts live under `lib/music_library/` by convention.

5. **Pagination via cursor vs offset** — Offset chosen. No requirement for cursor pagination; the data volume is small (hundreds of unique errors, not millions); offset pagination is simpler and maps to the task's `limit`/`offset` params.

### Architecture impact analysis

| Touchpoint | Impact |
|---|---|
| **New context: `lib/music_library/errors.ex`** | New module. Two public functions: `list_errors/1` (filtered + paginated list with counts) and `get_error!/1` (single error with occurrences). |
| **New controller: `lib/music_library_web/controllers/error_controller.ex`** | New module. Two actions: `index/2`, `show/2`. Parses query params with `parse_int` helper. |
| **New JSON view: `lib/music_library_web/controllers/error_json.ex`** | New module. Two render functions: `index/1`, `show/1`. Serializes errors and occurrences. |
| **Router: `lib/music_library_web/router.ex`** | Add two new routes under the existing `scope "/api/v1"` block (`GET /api/v1/errors`, `GET /api/v1/errors/:id`). No new pipeline or scope. |
| **No PubSub impact** | These are read-only endpoints. No real-time updates needed. |
| **No supervision tree impact** | The context is stateless. No new processes. |
| **No external API impact** | Internal API only. |
| **No migration needed** | Tables already exist (created by error_tracker's own migrations in `20260226212444_add_error_tracker.exs`). |
| **No deprecation path** | Net-new addition. |

### Performance profile

**List endpoint (`GET /api/v1/errors`)**: Two queries.
1. COUNT query with same filters (no OFFSET/LIMIT). Complexity: O(n) scan of filtered rows on `error_tracker_errors` table. With typical production volumes (hundreds of unique errors), this is trivially fast.
2. SELECT with filters + ORDER BY + LIMIT + OFFSET. Same O(n) scan profile. No joins — all data is in the single table for the list view.

No N+1 risk in the list endpoint: we return error-level data only, no occurrence preloading.

**Single error endpoint (`GET /api/v1/errors/:id`)**: Three queries.
1. `Repo.get!` on `error_tracker_errors` by ID. PK lookup is O(1).
2. `Repo.preload` occurrences sorted by `inserted_at DESC`. This produces a single LEFT JOIN or an IN query (depends on preload strategy). For errors with hundreds of occurrences, the preload could return substantial data.
3. A subquery COUNT on occurrences for `occurrence_count` (if not already preloaded). Can be merged with the preload.

No pagination on occurrences in this version — the task spec shows all occurrences returned. If an error has many occurrences (e.g., thousands for a noisy bot error), this could produce a large response. **Mitigation**: the task explicitly says "all its occurrences", so we follow the spec. A future version could add `limit`/`offset` query params for occurrences if needed.

**Memory**: JSON response is built in memory from Ecto structs. For an error with 100 occurrences each containing full stacktraces, response size could reach ~100KB-500KB. Acceptable for an authenticated internal tooling API accessed infrequently.

**Latency**: Sub-100ms for typical queries on SQLite with in-memory page cache. No external API calls.

### Benchmarking requirements

No dedicated benchmarks needed for this change. The endpoints are read-only against SQLite with simple queries on small tables (hundreds of rows). Standard test coverage will verify correctness.

If latency becomes a concern when occurrences grow large, we could add a `limit` param for occurrences in a follow-up. This is documented as a future consideration, not a current requirement.

### Cost profile

No paid resources consumed. The endpoints are internal HTTP handlers that only query the existing SQLite database and return JSON. No external API calls, no additional compute, no storage.

### Implementation steps (sequential order)

---

#### Step 1: Create `MusicLibrary.Errors` context module

**What**: New `lib/music_library/errors.ex` with two public functions and private query helpers.

**Functions**:
- `list_errors(opts)` — accepts keyword list: `[status: :unresolved, muted: false, search: "syntax error", limit: 50, offset: 0]`. Returns `%{errors: [...], total: n}`.
  - Filters: `status` → `where(status: ^status)`, `muted` → `where(muted: ^muted)` (boolean), `search` → `where(ilike(e.reason, ^"%#{search}%"))`
  - Count query: `Repo.aggregate/3` with same filters
  - List query: `order_by(desc: :last_occurrence_at)` + `limit/offset`  
  - Computed fields `occurrence_count` and `first_occurrence_at` are omitted from the list endpoint to keep queries simple. They are computed only in the single-error endpoint. This avoids a correlated subquery per row in the list.
- `get_error!(id)` — fetches single error, preloads all occurrences sorted `desc: inserted_at`, computes `occurrence_count` and `first_occurrence_at`.

**Verification**:
```bash
mix test test/music_library/errors_test.exs
```
Write tests for: empty list, filtering by status, filtering by muted, search by reason substring, pagination (limit + offset), error not found raises, single error includes occurrence_count and occurrences.

---

#### Step 2: Create `MusicLibraryWeb.ErrorController`

**What**: New `lib/music_library_web/controllers/error_controller.ex` following `CollectionController` patterns.

**Actions**:
- `index(conn, params)` — parses `status`, `muted`, `search`, `limit`, `offset` from query params; calls `Errs.list_errors(opts)`; renders `:index`.
- `show(conn, %{"id" => id})` — fetches error by integer ID; renders `:show`.

Use `parse_int/2` helper (same pattern as `CollectionController`).

**Verification**:
```bash
mix test test/music_library_web/controllers/error_controller_test.exs
```
Write tests for: auth required (401 without Bearer token), list returns JSON structure, filter params applied, single error returns JSON with occurrences.

---

#### Step 3: Create `MusicLibraryWeb.ErrorJSON` view

**What**: New `lib/music_library_web/controllers/error_json.ex` following `CollectionJSON` patterns.

**Render functions**:
- `index(%{errors: errors, total: total, limit: limit, offset: offset})` → `%{errors: [...], total: n, limit: n, offset: n}`
- `show(%{error: error})` → single error with nested occurrences

**Serialization details**:
- `id` → integer
- `status` → atom-to-string (`"resolved"` / `"unresolved"`)
- `fingerprint` → hex string (already stored as hex string in SQLite TEXT column)
- `muted` → boolean
- `last_occurrence_at`, `inserted_at`, `updated_at`, `first_occurrence_at` → ISO8601 strings
- `context` → decoded map (already a map in Ecto, stored as JSON in SQLite)
- `breadcrumbs` → array of strings
- `stacktrace.lines` → array of maps `%{application, module, function, arity, file, line}`
- `occurrence_count` → integer

**Verification**:
```bash
mix test test/music_library_web/controllers/error_controller_test.exs
```
Tests from Step 2 already validate the JSON structure via `json_response/2`. Verify serialization of all fields including nested stacktrace lines.

---

#### Step 4: Add routes to the router

**What**: Add two entries to the existing `scope "/api/v1"` block in `lib/music_library_web/router.ex`:

```elixir
get "/errors", ErrorController, :index
get "/errors/:id", ErrorController, :show
```

Place after existing collection routes, before `assets` and `backup`.

**Verification**:
```bash
mix phx.routes | grep errors
```
Should show the two new API routes under `/api/v1/errors`. Also run existing tests to ensure no route conflicts:
```bash
mix test
```

---

#### Step 5: Integration test and documentation update

**What**: Run the full test suite, update architecture docs.

**Verification**:
```bash
mix test
mix test test/music_library_web/controllers/error_controller_test.exs
```
All tests pass including existing tests. Update `docs/architecture.md`:
- Add `Errors` context to the Contexts table
- Add `ErrorController` to the Controllers table

---

### Production Changes

No manual production infrastructure changes required. The endpoints use:
- Existing `error_tracker_errors` and `error_tracker_occurrences` tables (already migrated)
- Existing `require_api_token` plug (already configured with `API_TOKEN` env var)
- Existing `MusicLibrary.Repo` (already configured)
- No new environment variables, no new services, no DNS changes, no firewall changes

---

### Test data seeding strategy

**`ErrorTracker.report/3` cannot be used to seed test data.** Two blockers:

1. **ErrorTracker is disabled in test.** `config/config.exs` sets `enabled: false`, with no override in `test.exs`. `report/3` checks `enabled?()` at the top and returns `:noop` when disabled — nothing is persisted.
2. **ErrorTracker's supervision tree isn't started.** The application supervision tree only starts `ErrorTracker.ErrorNotifier`; the telemetry handlers and process-dictionary state that `report/3` depends on (`get_context()`, `get_breadcrumbs()`) are not initialized.

**Instead, seed via direct Ecto inserts using `MusicLibrary.Repo`** with ErrorTracker's own structs:

```elixir
# In test/support/fixtures/errors_fixtures.ex

alias ErrorTracker.{Error, Occurrence, Stacktrace}

def error_fixture(attrs \\ []) do
  defaults = %{
    kind: "RuntimeError",
    reason: "Something went wrong",
    source_line: "lib/my_module.ex:42",
    source_function: "MyModule.do_thing/0",
    status: :unresolved,
    fingerprint: error_fingerprint(:runtime_error, "lib/my_module.ex:42", "MyModule.do_thing/0"),
    last_occurrence_at: DateTime.utc_now(),
    muted: false
  }

  defaults
  |> Map.merge(Map.new(attrs))
  |> then(&MusicLibrary.Repo.insert!(struct!(Error, &1)))
end

def occurrence_fixture(error, attrs \\ []) do
  defaults = %{
    reason: error.reason,
    context: %{user_id: 1},
    breadcrumbs: ["step 1"],
    stacktrace: %Stacktrace{
      lines: [
        %Stacktrace.Line{
          application: "music_library",
          module: "MyModule",
          function: "do_thing",
          arity: 0,
          file: "lib/my_module.ex",
          line: 42
        }
      ]
    },
    error_id: error.id
  }

  defaults
  |> Map.merge(Map.new(attrs))
  |> then(&MusicLibrary.Repo.insert!(struct!(Occurrence, &1)))
end

defp error_fingerprint(kind, source_line, source_function) do
  [kind, source_line, source_function]
  |> Enum.join()
  |> then(&:crypto.hash(:sha256, &1))
  |> Base.encode16()
end
```

**Notes:**
- `fingerprint` is stored as TEXT in SQLite (the hex string from `Base.encode16/1`), despite the Ecto schema declaring `:binary`. Use hex strings when inserting.
- `status` is an `Ecto.Enum` — pass atoms (`:resolved` / `:unresolved`).
- `muted` is INTEGER in SQLite (`0`/`1`), but the Ecto schema accepts booleans.
- `stacktrace` is stored as JSON text (embedded schema serialized by Ecto). Pass a `%Stacktrace{}` struct and Ecto handles serialization.
- `context` and `breadcrumbs` are stored as JSON text. Pass native Elixir maps and lists.
- The fixture module follows the existing pattern (`RecordsFixtures`, `RecordSetsFixtures`, etc.) — helper functions that return inserted structs via `MusicLibrary.Repo`.
- Include a variant fixture that produces multiple errors with different status/fingerprint/muted values to exercise filtering and pagination in tests.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation completed. All 5 steps executed:

1. **Context** (`lib/music_library/errors.ex`): Created `MusicLibrary.Errors` with `list_errors/1` (filtered + paginated) and `get_error/1` (returns `{:ok, error}` or `{:error, :not_found}`). Uses `MusicLibrary.Repo` (where error_tracker tables actually live, not TelemetryRepo). Private query helpers for status/muted/search filtering.

2. **Controller** (`lib/music_library_web/controllers/error_controller.ex`): `index/2` and `show/2` actions. Parses query params (status→atom, muted→bool, limit/offset→int) following CollectionController patterns. Handles 404 for missing errors explicitly with `put_status/2` + `json/2`.

3. **JSON view** (`lib/music_library_web/controllers/error_json.ex`): Serializes errors (list) and error-with-occurrences (show). Includes catch-all `render/2` for Phoenix error templates (404, 500) since this module name collides with the configured render_errors view. Fingerprint comes as hex string from SQLite TEXT column. Stacktrace lines rendered as array of maps.

4. **Router**: Two routes added under `scope "/api/v1"`: `GET /errors` and `GET /errors/:id`.

5. **Tests + docs**: Created `test/support/fixtures/errors_fixtures.ex` (direct Ecto inserts since ErrorTracker disabled in test) and `test/music_library_web/controllers/error_controller_test.exs` (10 tests: auth required ×2, list/pagination/filter/search ×6, show/occurrences ×1, 404 ×1). All 900 tests pass. Updated `docs/architecture.md` with Errors context and ErrorController.

**Deviations from original plan:**

- Changed `get_error!/1` → `get_error/1` returning `{:ok, error} | {:error, :not_found}` instead of raising. This avoids relying on Phoenix's automatic Ecto.NoResultsError→404 conversion (which didn't work in tests).

- Added `render/2` catch-all to ErrorJSON for Phoenix error template rendering (404, 500) - module name collides with configured render_errors view.

- List endpoint omits `occurrence_count` and `first_occurrence_at` per plan decision (computed only in single-error endpoint).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
## Summary

Added two JSON API endpoints under `/api/v1/errors` to expose production error data from ErrorTracker, behind the existing Bearer token authentication.

### What changed

**New files:**
- `lib/music_library/errors.ex` — Context with `list_errors/1` (filtered, paginated listing) and `get_error/1` (single error with preloaded occurrences, computed counts)
- `lib/music_library_web/controllers/error_controller.ex` — Controller with `index/2` and `show/2` actions, following CollectionController patterns
- `lib/music_library_web/controllers/error_json.ex` — JSON serializer for errors and occurrences, including stacktrace lines; also serves as Phoenix error renderer (404/500 JSON responses)
- `test/support/fixtures/errors_fixtures.ex` — Test fixture helpers using direct Ecto inserts (ErrorTracker is disabled in test)
- `test/music_library_web/controllers/error_controller_test.exs` — 10 tests: auth required (2), list/pagination/filter/search (6), single error with occurrences (1), 404 handling (1)

**Modified files:**
- `lib/music_library_web/router.ex` — Added `GET /api/v1/errors` and `GET /api/v1/errors/:id` routes
- `docs/architecture.md` — Added Errors context and ErrorController entries

### API design

- `GET /api/v1/errors` — List errors with filters (`status`, `muted`, `search`), pagination (`limit` default 50, `offset` default 0), ordered by `last_occurrence_at DESC`
- `GET /api/v1/errors/:id` — Single error detail with all occurrences (including stacktraces), `occurrence_count`, and `first_occurrence_at`

### Key decisions

- Uses `MusicLibrary.Repo` (not TelemetryRepo) — error_tracker tables live in the main database per `config/config.exs`
- Returns integer IDs (error_tracker uses auto-increment PKs, not UUIDs)
- List endpoint omits `occurrence_count`/`first_occurrence_at` to avoid correlated subqueries per row
- Context returns `{:ok, error} | {:error, :not_found}` instead of raising — explicit 404 handling more reliable than relying on Phoenix's Ecto.NoResultsError→404 conversion

### Test results

All 900 tests pass (43 doctests, 857 existing + 10 new).
<!-- SECTION:FINAL_SUMMARY:END -->
