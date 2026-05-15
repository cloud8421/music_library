---
name: testing
description: Use this skill when writing, running, debugging, or fixing ANY tests. Also use when the user mentions "test", "testing", "spec", "ExUnit", "assert", "fixture", "test helper", "test setup", "run the tests", "test failure", "failing test", "add a test", "write a test", "test coverage", "LiveViewTest", "PhoenixTest", "sandbox", or asks about test conventions. Use PROACTIVELY whenever creating or modifying test files, test/support modules, or when a code change requires test updates.
---

# Testing

Project-specific testing conventions, patterns, and pitfalls for the Music Library
codebase. These rules override generic Elixir/Phoenix testing defaults.

## Checklist Before Writing Any Test

1. **Feature setup stays in the test module that needs it**, not in shared case templates
   (`ConnCase`, `DataCase`). Only add to shared templates when EVERY test using that
   template genuinely needs it.

2. **Use fixture modules for test data.** Fixtures call through context functions (not
   raw `Repo.insert`). Use `System.unique_integer([:positive])` for unique names.

3. **Assert specific values, not just shapes.** Prefer `assert data == expected` over
   `assert data != nil` or `assert {:ok, _} = result`. Wildcard matches (`_`) signal the
   test is too vague.

4. **Error assertions must match the specific error type.** `assert {:error, _reason}` is
   too broad. Match the struct or atom: `%Req.TransportError{reason: :timeout}`, `:no_session_key`.

5. **Verify outcomes through context modules**, not just UI assertions. Delete tests
   should assert both `refute has_element?` AND `assert_raise Ecto.NoResultsError`.

6. **No boilerplate-only tests.** Don't add test files that just verify Phoenix generator
   output. Tests must exercise application behaviour.

## Running Tests

```bash
# All tests (partitioned, like CI)
mise run test

# Specific file
mix test test/music_library/records_test.exs

# Specific test by line number
mix test test/music_library/records_test.exs:123

# With tags
mix test --only tag_name
mix test --only logged_out

# Limit failures for faster feedback
mix test --max-failures 5
```

## Test Styles — When to Use Each

### PhoenixTest (`visit`, `click_button`, `click_link`, `fill_in`, `assert_has`)

The **primary framework** for all LiveView page-level tests. Prefer PhoenixTest over
`Phoenix.LiveViewTest.live/2` for all new and migrated tests.

```elixir
# Navigation and assertions
conn
|> visit(~p"/collection")
|> assert_has("h1", "My Collection")
|> click_link("Next Page")
|> assert_path(~p"/collection?page=2")

# Form interactions
conn
|> visit(~p"/record-sets/new")
|> fill_in("Name", with: "Favorites")
|> click_button("Save Set")
|> assert_has("p", "Favorites")
```

### ConnCase Auto-Imports

`MusicLibraryWeb.ConnCase` auto-imports the following LiveViewTest functions (with `only:`):
- `render_async/1`, `render_change/1`, `render_click/3`
- `render_hook/2`, `render_hook/3`
- `element/2`, `element/3`
- `form/3`

It also imports `PhoenixTest` in full. When a test needs LiveViewTest functions NOT in
the auto-import list (e.g. `render_click/1`, `render_submit/1`), add an explicit
`only:` import to the test file rather than importing the whole module.

### The `unwrap/2` Escape Hatch

When PhoenixTest can't handle an interaction directly, use `unwrap/2` to access the
underlying `Phoenix.LiveViewTest.View` and call LiveViewTest functions directly.
`unwrap/2` handles redirects automatically and returns a PhoenixTest session.

```elixir
# Trigger a JS hook event
unwrap(session, &render_hook(&1, "reorder", %{"record_ids" => [3, 1, 2]}))

# Submit a form inside a LiveComponent (phx-target={@myself})
unwrap(session, fn view ->
  view
  |> form("#record-picker-navigation form", %{query: "search term"})
  |> render_submit()
end)

# Click a non-button/non-link element with phx-click
unwrap(session, fn view ->
  view
  |> element("li[phx-click='add_record'][phx-value-record-id='#{id}']")
  |> render_click()
end)
```

### Context Tests (standard ExUnit + DataCase)

Use for **business logic** that doesn't involve the web layer:

```elixir
assert {:ok, %Record{}} = Records.create_record(valid_attrs)
```

## SQLite Test Gotchas

### Timestamp precision

SQLite `utc_datetime` has **second-level precision**. Rapid inserts get identical
timestamps, breaking ordering assertions:

```elixir
# DON'T rely on auto-timestamps for ordering
record1 = record_fixture()
record2 = record_fixture()

# DO manually set timestamps when order matters
{:ok, record1} = Repo.update_all(Record, set: [inserted_at: ~N[2024-01-01 00:00:00]])
{:ok, record2} = Repo.update_all(Record, set: [inserted_at: ~N[2024-01-02 00:00:00]])
```

### VACUUM / low-level ops

Database operations like `VACUUM` cannot run in the test sandbox. **Do not write a test**
that asserts the sandbox error message — delete or skip it.

## Swoosh Email Testing

Use `Swoosh.Adapters.Sandbox`, NOT `Swoosh.Adapters.Test`:

```elixir
setup do
  SwooshSandbox.checkout()
  on_exit(fn -> SwooshSandbox.checkin() end)
end
```

When the mailer is invoked from a **separate process** (e.g., a GenServer started in
the test), share the sandbox:

```elixir
SwooshSandbox.allow(self(), gen_server_pid)
```

## API Stubs (Req.Test)

All external HTTP calls are stubbed in tests via `config/test.exs` using `Req.Test`.
Each API has fixture modules that provide realistic response data.

When adding a new API call, you must:
1. Add a stub in `config/test.exs`
2. Use fixture data from the appropriate fixtures module
3. Ensure the stub covers error cases too (rate limiting, auth errors, 404s)

## Worker Tests

Workers that enqueue other jobs MUST use `assert_enqueued`:

```elixir
# DON'T just check perform_job return value
assert {:ok, []} = perform_job(worker, args)

# DO verify downstream enqueues
assert_enqueued(worker: SomeDownstreamWorker, args: %{id: id})
```

Worker return value testing:
```elixir
# Success
assert :ok = perform_job(MyWorker, %{id: id})

# Transient error (Oban will retry)
assert {:error, :rate_limit} = perform_job(MyWorker, %{id: id})

# Permanent termination
assert {:cancel, :no_english_wikipedia} = perform_job(MyWorker, %{id: id})
```

## Don't Duplicate Assertions

### Don't test the same guard at every call site

If a shared check (e.g., session key presence) is enforced in one place, test it once.
Don't duplicate the same assertion across every function that calls the shared check.

### Consolidate identical assertions across endpoints

When multiple routes share the same plug/middleware behaviour (e.g., auth), test it
once with a loop or parameterised approach, not N separate identical tests.

## Test File Migration Checklist (LiveViewTest → PhoenixTest)

When converting a test file from `Phoenix.LiveViewTest.live/2` to `PhoenixTest.visit/2`:

1. **Replace `import Phoenix.LiveViewTest`** with explicit `only:` imports for any
   functions still needed (see ConnCase auto-imports above). Common additions:
   `render_click: 1`, `render_submit: 1`, `render_change: 1`, `form: 3`.

2. **Replace `live(conn, path)`** with `visit(conn, path)`. The session returned by
   `visit` pipes into all PhoenixTest helpers.

3. **Replace `form/3` + `render_submit/1`** with `fill_in/3` + `click_button/2` (for
   standard inputs with labels) or `unwrap` with `form/3` + `render_submit/1` (for
   forms inside LiveComponents without labeled inputs).

4. **Replace `form/3` + `render_change/1`** with `fill_in/3` (triggers `phx-change`
   automatically) or `unwrap` with `form/3` + `render_change/1` (for Fluxon custom
   components or label-less inputs).

5. **Replace `element/2` + `render_click/1`** with `click_button/2` (for `<button>`)
   or `click_link/2` (for `<a>`), or `unwrap` with `element/2` + `render_click/1`
   (for `<li>`, `<span>`, or other non-standard clickable elements).

6. **Replace `render_hook/3`** with `unwrap(&render_hook(&1, event, value))`.

7. **Replace `assert_redirect(view, path)`** with `assert_path(session, path)`.

8. **Replace `has_element?(view, selector)`** with `assert_has(session, selector)` or
   `refute_has(session, selector)`.

9. **Replace `render(view)` with substring checks** (`html =~ "text"`) with
   `assert_has(session, selector, text)` or `assert_has(session, selector, text: text)`.

10. **For position-based assertions** (e.g., verifying alphabetical order in HTML),
    access raw HTML via `Phoenix.LiveViewTest.render(session.view)`.

## Known Blockers for Full PhoenixTest Migration

These patterns currently require LiveViewTest and cannot be fully migrated:

| Pattern | Reason | Workaround |
|---------|--------|------------|
| `send(view.pid, msg)` | Direct process messaging to LiveView | Keep `live/2` for these tests |
| `live_isolated/3` | Testing LiveComponents in isolation | Keep `live_isolated` for these tests |
| `send_update/3` | Updating LiveComponent state directly | Keep `send_update` for these tests |
| `<span phx-click>` (Fluxon badges) | PhoenixTest only supports `<a>` and `<button>` | Refactor to `<button>` or use `unwrap` |
| `<li phx-click>` (custom click targets) | PhoenixTest only supports `<a>` and `<button>` | Use `unwrap` with `element/2` + `render_click/1` |

## Test Organization

### Tags

```elixir
@tag :logged_out     # Public endpoint tests (no auth)
@tag :capture_log    # Tests with expected error log output

# Run only tagged tests
mix test --only logged_out
```

### Test modules structure

```
test/
├── music_library/         # Context tests
├── music_library_web/     # LiveView/controller tests
└── support/
    ├── conn_case.ex       # HTTP test setup
    ├── data_case.ex       # Database sandbox
    ├── live_test_helpers.ex
    └── fixtures/          # Fixture modules
```

### Available fixture modules

| Module | Creates |
|--------|---------|
| `RecordsFixtures` | Records with MusicBrainz data |
| `RecordSetsFixtures` | Record sets with items |
| `OnlineStoreTemplatesFixtures` | Store templates |
| `ArtistInfoFixtures` | ArtistInfo records |
| `ScrobbleRulesFixtures` | Scrobble rules |
| `ScrobbledTracksFixtures` | Last.fm tracks |
| `Discogs.ArtistFixtures` | Discogs API responses |
| `LastFm.ArtistFixtures` | Last.fm API responses |
| `MusicBrainz.*Fixtures` | MusicBrainz API responses |
| `Wikipedia.Fixtures` | Wikipedia API responses |

Always call through the fixture module — never `Repo.insert` directly.

## PhoenixTest Patterns and Pitfalls

### `assert_has` / `refute_has` Signatures

PhoenixTest provides multiple `assert_has` arities. Use the convenience form for
text matching (no `text:` keyword needed):

```elixir
# Selector only
assert_has(session, "#record-picker-search-input")

# Selector + text (convenience — wraps in text: keyword)
assert_has(session, "h3", "Collected")
assert_has(session, "[data-part='error']", "can't be blank")

# Selector + keyword opts
assert_has(session, "h1", text: "Add Record")
assert_has(session, ".posts", count: 2)

# Selector + text + keyword opts
assert_has(session, "h1", "Hello", count: 2)
```

### Duplicate Button Texts — Scoped Selectors

When a page has multiple buttons with the same visible text (e.g., "Delete" in
dropdown menus), use a scoped CSS selector:

```elixir
click_button(session, "button[phx-click='delete_set']", "Delete")
click_button(session, "#record_1 button[phx-click='delete']", "Delete")
```

### Forms Inside LiveComponent Modals (`phx-target={@myself}`)

PhoenixTest handles forms inside LiveComponents automatically. Fill in fields and
click submit as usual — the `phx-target` routing is handled internally:

```elixir
conn
|> visit(~p"/record-sets/new")
|> fill_in("Name", with: "My Set")        # form targets the LiveComponent
|> click_button("Save Set")                # submit routes to LiveComponent
|> assert_has("p", "My Set")               # verify on index after redirect
```

### Fluxon Custom `<.select>` Components

This project uses Fluxon custom select components (not native `<select>`).
`PhoenixTest.select/3` does NOT work with these — the label's `for` attribute points
to a toggle button, not a `<select>` element.

Use `unwrap` with `form/3` + `render_change/1` instead:

```elixir
defp set_rule_type(session, type) do
  unwrap(session, fn view ->
    view
    |> form("#scrobble_rule-form", scrobble_rule: %{type: type})
    |> render_change()
  end)
end
```

### `<li>` and `<span>` Elements with `phx-click`

PhoenixTest's `click_button` only supports `<button>`, `[role="button"]`, and
`<input type="button|submit|...">`. `click_link` only supports `<a>`.

For `<li phx-click="...">` or `<span phx-click="...">` elements, use `unwrap` with
`element/2` + `render_click/1`:

```elixir
unwrap(session, fn view ->
  view
  |> element("li[phx-click='add_record'][phx-value-record-id='#{id}']")
  |> render_click()
end)
```

This is a **blocking limitation** — if an interaction relies on clicking non-standard
elements, consider refactoring to a `<button>` with proper accessible text.

### Edit-Form Validation with Existing Data

When testing validation on an edit form, the form is pre-populated with existing
data. Clicking "Save" without clearing fields will NOT trigger "can't be blank"
errors. Use `unwrap` with `render_change` to clear fields first:

```elixir
conn
|> visit(~p"/scrobble-rules/#{rule}/edit")
|> unwrap(fn view ->
  view
  |> form("#scrobble_rule-form",
    scrobble_rule: %{type: "", match_value: "", target_musicbrainz_id: ""}
  )
  |> render_change()
end)
|> assert_has("*", "can't be blank")
```

### `assert_path` and Patch Links

`assert_path` on `push_patch` links does NOT capture query params from the patch.
Use path-only assertions for patch navigation:

```elixir
# DON'T — query params won't match after a patch
assert_path(session, ~p"/scrobble-rules/#{rule}/edit?#{[page: 1, page_size: 50]}")

# DO — path only, or use query_params for LiveView `handle_params`-visible params
assert_path(session, ~p"/scrobble-rules/#{rule}/edit")
```

For navigation via `push_navigate` or `push_patch` with known query params visible
in the browser URL, `assert_path` with `query_params:` works correctly:

```elixir
|> click_link("a[href*='order=alphabetical']", "A->Z")
|> assert_path(~p"/scrobble-rules", query_params: %{order: "alphabetical"})
```

### Inputs Without Visible Labels

PhoenixTest's `fill_in` requires a `<label>` associated with the input. Inputs with
only a `placeholder` cannot be targeted directly.

For search forms without labels, use `unwrap` with `form/3` + `render_change/1`
to trigger the search handler:

```elixir
defp search_rules(session, query) do
  unwrap(session, fn view ->
    view
    |> form("form[phx-change='search']:not([phx-target])", %{query: query})
    |> render_change()
  end)
end
```

### Testing JS Hooks

Use `render_hook/3` for testing JS hook interactions:

```elixir
assert render_hook(view, "music_library:clipcopy", %{text: "copy me"}) =~ "copy me"
```

## Testing `handle_async`

For async operations in LiveView tests, use `unwrap(&render_async/1)` which handles
the async resolution and returns a PhoenixTest session:

```elixir
conn
|> visit(~p"/maintenance")
|> unwrap(&render_async/1)
|> assert_has("span", "Connected as alice")
```

For unit testing `handle_async/3` callbacks, always handle all three cases:

```elixir
assert {:noreply, socket} = handle_async(socket, :task_ref, {:ok, {:ok, result}})
assert {:noreply, socket} = handle_async(socket, :task_ref, {:ok, {:error, reason}})
assert {:noreply, socket} = handle_async(socket, :task_ref, {:exit, reason})
```

## Oban in Tests

Oban runs in **manual testing mode** — jobs don't auto-execute. Use `perform_job/2`
from `Oban.Testing` to execute them explicitly.
