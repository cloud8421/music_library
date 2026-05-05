---
id: ML-165
title: Mute and resolve production errors from pi
status: Done
assignee: []
created_date: "2026-05-05 11:20"
updated_date: "2026-05-05 12:27"
labels: []
dependencies: []
references:
  - >-
    doc-12 -
    Research-Mute-and-Resolve-Production-Errors-Implementation-Routes.md
modified_files:
  - lib/music_library/errors.ex
  - lib/music_library_web/controllers/error_controller.ex
  - lib/music_library_web/controllers/error_json.ex
  - lib/music_library_web/router.ex
  - test/music_library/errors_test.exs
  - test/music_library_web/controllers/error_controller_test.exs
  - .pi/extensions/prod-errors/index.ts
  - docs/architecture.md
priority: medium
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Extend the production error tooling in pi so that it's possible to:

1. Mute and resolve issues from the `prod-errors` TUI (user action)
2. Mute and resolve issues via a tool (pi action)

There are no endpoints for these two actions, so we would need to extend the application's v1/api/ endpoints to support them.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 POST /api/v1/errors/:id/mute sets muted=true and returns 200 with updated error
- [x] #2 POST /api/v1/errors/:id/unmute sets muted=false and returns 200 with updated error
- [x] #3 POST /api/v1/errors/:id/resolve sets status=:resolved and returns 200 with updated error
- [x] #4 POST /api/v1/errors/:id/unresolve sets status=:unresolved and returns 200 with updated error
- [x] #5 All four POST endpoints return 401 without Bearer token
- [x] #6 All four POST endpoints return 404 for non-existent error ID
- [x] #7 All four POST endpoints return 404 for non-integer ID
- [x] #8 pi tools (mute_production_error, unmute_production_error, resolve_production_error, unresolve_production_error) work correctly
- [x] #9 /prod-errors TUI: M key toggles mute state on selected error with visual feedback
- [x] #10 /prod-errors TUI: R key toggles resolve/unresolve status on selected error with visual feedback
- [x] #11 /prod-errors TUI help text shows new M and R keybindings
- [x] #12 All context function tests pass
- [x] #13 All controller tests pass
- [x] #14 Documentation updated: docs/architecture.md reflects new endpoints and context description
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan: Route A — Four dedicated POST endpoints

### Overview

Add four API endpoints (`/mute`, `/unmute`, `/resolve`, `/unresolve`) under `POST /api/v1/errors/:id/`, matching context functions in `MusicLibrary.Errors`, controller actions in `MusicLibraryWeb.ErrorController`, four pi tools, and TUI keybindings in the `/prod-errors` browser.

### Step 1: Add context functions (`MusicLibrary.Errors`)

**File:** `lib/music_library/errors.ex`

Add four public functions and one private helper:

```elixir
@spec mute_error(pos_integer()) :: {:ok, Error.t()} | {:error, :not_found | Ecto.Changeset.t()}
def mute_error(id), do: update_error_field(id, :muted, true)

@spec unmute_error(pos_integer()) :: {:ok, Error.t()} | {:error, :not_found | Ecto.Changeset.t()}
def unmute_error(id), do: update_error_field(id, :muted, false)

@spec resolve_error(pos_integer()) :: {:ok, Error.t()} | {:error, :not_found | Ecto.Changeset.t()}
def resolve_error(id), do: update_error_field(id, :status, :resolved)

@spec unresolve_error(pos_integer()) :: {:ok, Error.t()} | {:error, :not_found | Ecto.Changeset.t()}
def unresolve_error(id), do: update_error_field(id, :status, :unresolved)

defp update_error_field(id, field, value) do
  with %Error{} = error <- Repo.get(Error, id),
       {:ok, updated} <- error |> Ecto.Changeset.change([{field, value}]) |> Repo.update() do
    {:ok, updated}
  else
    nil -> {:error, :not_found}
    {:error, changeset} -> {:error, changeset}
  end
end
```

Place public functions after existing `get_error/1`, private helper at bottom with other private functions.

**Verification:** `mix test test/music_library/errors_test.exs` (after adding tests in Step 5)

### Step 2: Add controller actions (`MusicLibraryWeb.ErrorController`)

**File:** `lib/music_library_web/controllers/error_controller.ex`

Add four actions (`mute/2`, `unmute/2`, `resolve/2`, `unresolve/2`). Each:

1. Parses the `id` param via `Integer.parse/1`
2. Calls the corresponding context function
3. Renders the updated error on success, returns 404/422 on failure

```elixir
def mute(conn, %{"id" => id}), do: perform_action(conn, id, &Errors.mute_error/1)
def unmute(conn, %{"id" => id}), do: perform_action(conn, id, &Errors.unmute_error/1)
def resolve(conn, %{"id" => id}), do: perform_action(conn, id, &Errors.resolve_error/1)
def unresolve(conn, %{"id" => id}), do: perform_action(conn, id, &Errors.unresolve_error/1)

defp perform_action(conn, id, action_fn) do
  case Integer.parse(id) do
    {id_int, ""} when id_int > 0 ->
      case action_fn.(id_int) do
        {:ok, error} ->
          render(conn, :update, error: error)
        {:error, :not_found} ->
          conn |> put_status(:not_found) |> json(%{error: "Not Found"})
        {:error, _changeset} ->
          conn |> put_status(:unprocessable_entity) |> json(%{error: "Update failed"})
      end
    _ ->
      conn |> put_status(:not_found) |> json(%{error: "Not Found"})
  end
end
```

**Verification:** `mix test test/music_library_web/controllers/error_controller_test.exs` (after adding tests in Step 5)

### Step 3: Add JSON render function

**File:** `lib/music_library_web/controllers/error_json.ex`

Add an `update/1` render function that returns the updated error (Phoenix maps the template atom `:update` to the function `update/1`):

```elixir
def update(%{error: error}) do
  %{error: error(error)}
end
```

Place near the existing `show/1` function.

**Verification:** Controller tests will exercise this indirectly; the rendered JSON should contain the updated error fields reflecting the mutation that was performed.

### Step 4: Add routes

**File:** `lib/music_library_web/router.ex`

Add four POST routes inside the `scope "/api/v1"` block, after the existing error GET routes:

```elixir
post "/errors/:id/mute", ErrorController, :mute
post "/errors/:id/unmute", ErrorController, :unmute
post "/errors/:id/resolve", ErrorController, :resolve
post "/errors/:id/unresolve", ErrorController, :unresolve
```

**Verification:** `mix test test/music_library_web/controllers/error_controller_test.exs` (auth tests should verify 401 for all four)

### Step 5: Add tests

**File:** `test/music_library/errors_test.exs`

Add a `describe "mute_error/1, unmute_error/1, resolve_error/1, unresolve_error/1"` block with tests for:

- `mute_error/1` sets `muted` to `true`
- `unmute_error/1` sets `muted` to `false`
- `resolve_error/1` sets `status` to `:resolved`
- `unresolve_error/1` sets `status` to `:unresolved`
- Returns `{:error, :not_found}` for non-existent ID
- **Idempotency for all four actions**: calling mute on already-muted error succeeds (no-op), unmute on already-unmuted succeeds, resolve on already-resolved succeeds, unresolve on already-unresolved succeeds

**File:** `test/music_library_web/controllers/error_controller_test.exs`

Add a `describe "POST /api/v1/errors/:id/mute|unmute|resolve|unresolve"` block with tests for:

- Each endpoint returns 401 without Bearer token
- Each endpoint returns 200 with updated error on success
- Each endpoint returns 404 for non-existent ID
- Each endpoint returns 404 for non-integer ID

**Verification:** `mix test test/music_library/errors_test.exs test/music_library_web/controllers/error_controller_test.exs` — all tests pass.

### Step 6: Add pi tools

**File:** `.pi/extensions/prod-errors/index.ts`

Register four new tools after the existing `fetch_production_error` tool:

1. **`mute_production_error`** — POSTs to `/api/v1/errors/:id/mute`
2. **`unmute_production_error`** — POSTs to `/api/v1/errors/:id/unmute`
3. **`resolve_production_error`** — POSTs to `/api/v1/errors/:id/resolve`
4. **`unresolve_production_error`** — POSTs to `/api/v1/errors/:id/unresolve`

Each tool:

- Takes a single `id` (number) parameter
- Validates env vars (`PI_API_TOKEN`, `PI_SERVICE_FQDN_WEB`) like existing tools
- Makes a POST request with Bearer auth
- Returns a success message with the updated error in details, or an error message
- Has appropriate `promptSnippet` and `promptGuidelines`

Add a shared helper `postApi<T>` for POST requests (similar to the existing `fetchApi<T>` for GET, adding `method: "POST"`).

Add prompt guidelines:

- `mute_production_error`: "Use mute_production_error to silence notifications for a noisy or already-addressed production error."
- `unmute_production_error`: "Use unmute_production_error to re-enable notifications for a previously muted error."
- `resolve_production_error`: "Use resolve_production_error to mark a production error as resolved when the underlying issue has been fixed."
- `unresolve_production_error`: "Use unresolve_production_error to reopen a production error when it reoccurs after being resolved."

**Verification:** In a pi session, call `mute_production_error` with a known error ID — verify response shows success. Repeat for the other three tools.

### Step 7: Add TUI keybindings

**File:** `.pi/extensions/prod-errors/index.ts`

Add to the `ErrorBrowser` class:

1. **New methods:**
   - `toggleMute(id, currentMuted)` — POSTs to mute or unmute endpoint, updates local error state on success, shows notification on failure
   - `toggleResolve(id, currentStatus)` — POSTs to resolve or unresolve endpoint, updates local error state on success, shows notification on failure

2. **New keybindings** in `handleInput`:
   - `M` (shift+m) in list mode: calls `toggleMute` on the selected error
   - `R` (shift+r) in list mode: calls `toggleResolve` on the selected error
   - `M` in detail mode: calls `toggleMute` on the displayed error
   - `R` in detail mode: calls `toggleResolve` on the displayed error

   Lowercase `m` and `r` remain the existing filter toggles (muted filter, resolved filter).

3. **Update help text** in `renderList` and `renderDetail` to show the new keys.

Keybinding logic (list mode):

```
M → if error.muted → POST /unmute; else → POST /mute
R → if error.status === "resolved" → POST /unresolve; else → POST /resolve
```

After a successful API call, update the local `ErrorListItem` in `this.errors` and call `this.invalidate()`.

**Visual feedback on success:**

- The error's list entry re-renders immediately: the `[MUTED]` label appears/disappears, and the status badge (`[RESOLVED]` / `[UNRESOLVED]`) updates.
- In detail mode, the header line (`Status: … | Muted: …`) updates on next render.
- On failure: a toast notification via `this.notify()` displays the error message.

**Verification:** Run `/prod-errors` in pi, navigate to an error, press `M` — verify the muted state toggles and the `[MUTED]` label appears/disappears on the error line. Press `R` — verify the resolved status badge toggles. In detail mode, verify the same keys work and the header updates. Verify help text shows the new keys.

### Step 8: Update documentation

**File:** `lib/music_library/errors.ex`

Update the `@moduledoc` to reflect that the module now handles both queries and mutations. The current text describes it as read-only — add a line noting that it also provides `mute_error/1`, `unmute_error/1`, `resolve_error/1`, and `unresolve_error/1` for mutating error state.

**File:** `docs/architecture.md`

- Under the Routes section (if it enumerates API routes), add the four new POST endpoints: `/api/v1/errors/:id/mute`, `/api/v1/errors/:id/unmute`, `/api/v1/errors/:id/resolve`, `/api/v1/errors/:id/unresolve`.
- Under Contexts → `Errors`, update the description from "Read-only queries" to "Queries and mutations for production error data". Note that muting an error suppresses future email notifications via `ErrorTracker.ErrorNotifier` (which checks the `muted` field before dispatching).
- Under the Controller table, update the `ErrorController` row to include the four new action routes.

---

## Architecture Impact Summary

| Component                                                      | Change                                                                 |
| -------------------------------------------------------------- | ---------------------------------------------------------------------- |
| `MusicLibrary.Errors`                                          | +4 public functions, +1 private helper, updated moduledoc              |
| `MusicLibraryWeb.ErrorController`                              | +4 actions, +1 private helper                                          |
| `MusicLibraryWeb.ErrorJSON`                                    | +1 render function                                                     |
| `MusicLibraryWeb.Router`                                       | +4 POST routes                                                         |
| `.pi/extensions/prod-errors/index.ts`                          | +4 tools, +2 TUI methods, +2 keybindings, updated help text            |
| `test/music_library/errors_test.exs`                           | +~8 tests (including idempotency for all four actions)                 |
| `test/music_library_web/controllers/error_controller_test.exs` | +~12 tests                                                             |
| `docs/architecture.md`                                         | Update errors context description, add routes, update controller table |

**No changes:** supervision tree, PubSub, schemas, migrations, Oban workers, LiveViews, external APIs, production infrastructure.

**Interaction with ErrorTracker.ErrorNotifier:** The existing notifier (supervised in the application) already checks `error.muted` before dispatching email notifications. Muting an error via this API will therefore immediately suppress future email alerts for that error — this is the desired behavior and is consistent with how the ErrorTracker web dashboard's mute button works.

## Performance

- **DB:** Single-row UPDATE by primary key → O(1), ~1–5ms in WAL-mode SQLite
- **No N+1 risk:** No joins, no preloads
- **HTTP:** Minimal JSON encoding overhead
- **Concurrency:** SQLite serializes writes — negligible for low-frequency admin actions

## Cost

Zero incremental cost. No external API calls.

## Production Infrastructure

No changes needed (no new env vars, no DNS, no firewall, no special migration handling).

<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## Summary

Added mute/unmute/resolve/unresolve capability for production errors across the full stack:

### Backend (Elixir/Phoenix)

- **`MusicLibrary.Errors`**: Added 4 public functions (`mute_error/1`, `unmute_error/1`, `resolve_error/1`, `unresolve_error/1`) that delegate to `ErrorTracker`'s built-in mutation functions. `resolve/1` and `unresolve/1` handle the idempotent case (already-resolved/already-unresolved) gracefully.
- **`MusicLibraryWeb.ErrorController`**: Added 4 POST actions (`mute/2`, `unmute/2`, `resolve/2`, `unresolve/2`) with a shared `perform_action/3` helper that parses integer IDs, delegates to context, and returns proper JSON responses (200, 404, 422).
- **`MusicLibraryWeb.ErrorJSON`**: Added `update/1` render function for the `:update` template atom.
- **`MusicLibraryWeb.Router`**: Added 4 POST routes under the authenticated `/api/v1` scope.

### Tests

- **Context tests** (9 new): Test all four functions on success, not_found, and idempotency for each.
- **Controller tests** (6 auth + 6 functional): Test 401 without token, 200 with updated state, 404 for non-existent/non-integer IDs.

### Pi Extension (TypeScript)

- **`postApi<T>` helper**: Shared POST request helper with Bearer auth and validation.
- **4 new tools**: `mute_production_error`, `unmute_production_error`, `resolve_production_error`, `unresolve_production_error` — each takes an error ID, POSTs to the corresponding endpoint, and returns success/error.
- **TUI keybindings**: `M` (Shift+M) toggles mute, `R` (Shift+R) toggles resolve/unresolve on the selected error in both list and detail modes. Local state updates immediately on success with toast notifications.
- **Help text**: Updated in both list and detail modes to show the new keys.

### Documentation

- `docs/architecture.md`: Updated Errors context description from "Read-only" to "Queries and mutations", added new POST routes to ErrorController table.
- `lib/music_library/errors.ex`: Updated `@moduledoc` to reflect mutation capabilities.

### Design decisions

- Used `ErrorTracker.mute/1`, `unmute/1`, `resolve/1`, `unresolve/1` (which emit telemetry events) rather than raw `Ecto.Changeset.change/2`
- `resolve_error/1` and `unresolve_error/1` handle the already-resolved/unresolved case explicitly (ErrorTracker's functions pattern-match on current state and would crash otherwise)
- POST endpoints return the updated error as JSON (consistent with GET responses), using the same `error/1` render helper
<!-- SECTION:FINAL_SUMMARY:END -->
