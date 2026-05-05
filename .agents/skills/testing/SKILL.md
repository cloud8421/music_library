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

### PhoenixTest (`assert_has`, `click_button`, `click_link`, `visit`)

Use for **page-level LiveView tests** where you're testing navigation and DOM presence:

```elixir
{:ok, view, _html} = live(conn, ~p"/collection")
assert_has(view, ".record-card")
```

### Phoenix.LiveViewTest (`form/3`, `render_submit/1`, `element/2`, `render_click/1`)

Use for **LiveComponent interactions** where `phx-target={@myself}` is involved:

```elixir
html = render_submit(form(view, "#record-form", record: attrs))
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

## Testing JS Hooks

Use `render_hook/3` for testing JS hook interactions:

```elixir
assert render_hook(view, "music_library:clipcopy", %{text: "copy me"}) =~ "copy me"
```

## Testing `handle_async`

Always handle all three cases:

```elixir
assert {:noreply, socket} = handle_async(socket, :task_ref, {:ok, {:ok, result}})
assert {:noreply, socket} = handle_async(socket, :task_ref, {:ok, {:error, reason}})
assert {:noreply, socket} = handle_async(socket, :task_ref, {:exit, reason})
```

## Oban in Tests

Oban runs in **manual testing mode** — jobs don't auto-execute. Use `perform_job/2`
from `Oban.Testing` to execute them explicitly.
