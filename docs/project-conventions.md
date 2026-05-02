# Project Conventions

Rules extracted from commit history that are specific to this project and not already covered by `CLAUDE.md` usage rules.

## Commit Messages

- Imperative present tense, single-line, under 60 characters
- Describe intent/behavior, not implementation details
- Reverts use `Revert "Original message"` convention
- NEVER ADD a "Co-Authored-By" reference in the message body
- **When the work maps to a Backlog.md task, prefix the commit subject with the task identifier**, e.g. `ML-3: fix scrobble rule ordering`. The prefix counts toward the 60-character limit.
- **Dependency updates use `Update dependencies` for mix and `Update npm dependencies` for npm.** The subject describes the intent, not the mechanics — never use "bump". List each specific version change in the commit body as `package_name from => to`.

## Workflow

- **Backlog.md is the source of truth for task management.** The project has the Backlog.md MCP server configured; use it (via the MCP tools) for creating, viewing, and updating tasks. Do not invent a parallel tracking system.
- **All work that maps to a Backlog.md task must reference the task identifier in the commit subject** (see Commit Messages above). One commit can reference one task; if a single change spans multiple tasks, that is a signal to split the commit.
- When creating a Backlog.md task, **make sure you fill all task sections of the task**. It's critical you write an implementation plan in the task.
- When working on a Backlog.md task, **make sure to read the implementation plan included in the task, and follow it**. If the plan is outdated compared to the conditions of the codebase, notify the user.
- **GitHub issues are legacy and read-only for the agent.** Never create, comment on, close, or reopen GitHub issues — only the user does that. When asked about "the issue tracker" or "open issues", reach for Backlog.md, not `gh issue`.

## Architecture

- **Context modules own all queries.** LiveViews never query the database directly -- they call context functions.
- **Schemas hold pure accessor/helper functions** on the struct (e.g., `RecordSet.count_by_status/1`). No side effects in schemas.
- **LiveView standard structure:** `mount/3` sets `@current_section`, `handle_params/3` loads data and sets `@page_title` (via pattern-matched private `page_title/2`), `handle_info/2` receives LiveComponent messages.
- **LiveComponents communicate with parent** via `send(self(), {__MODULE__, msg})`.
- **Function components go in domain-specific modules:** `CoreComponents` for generic UI, `RecordComponents` for records, `ScrobbleComponents` for scrobbles, `SearchComponents` for search.
- **External API integrations** follow a three-module pattern: Facade (public API), API (Req HTTP client), Config (NimbleOptions).
- **Behaviours are separate modules** containing only `@callback` definitions. Concrete implementations use `@behaviour` and `@impl true`.
- **Oban workers are thin wrappers** that delegate to context modules. `perform/1` should be minimal.
- **Shared utilities** live at parent namespace level (`MusicLibrary.Batch`, not `MusicLibrary.Records.Batch`).
- **Domain sub-modules group under their context.** Modules strongly related to a context live as sub-modules (e.g., `Chats.StreamProvider`, `Chats.RecordChat`), distinct from shared utilities which live at the parent namespace level.
- **Structured search uses NimbleParsec-based `SearchParser` sub-modules.** Each context that supports `key:value` search syntax has a `SearchParser` sub-module (e.g., `Records.SearchParser`, `ListeningStats.SearchParser`) using NimbleParsec. Parsers support quoted multi-word values, free-text fallback, and normalize results into a map. Tests use doctests on the `parse/1` function.
- **Shared LiveView logic goes in `LiveHelpers.*` modules.** Event handlers, param parsing, and rendering helpers used across 2+ LiveViews are extracted to `LiveHelpers.*` rather than duplicated. When shared helpers need per-caller configuration (routes, labels, context modules), the calling LiveView defines a private config function (e.g., `index_config/0`) and assigns the resulting map in `mount/3`; the helper module reads it from `socket.assigns`.

## Extraction / Refactoring

- Extract when duplicated 3+ times. Identical template markup in 3+ places becomes a function component.
- Delete thin wrapper modules with a single caller -- inline them instead.
- Parameterize the differences when extracting shared logic.
- **When modifying an existing shared component**, refactor all callers to the unified new behavior rather than adding a mode/variant attr. Keep shared components to a single render path.
- Private helpers go at module bottom, public functions first.

## Template / UI

- **Gettext wraps ALL user-facing strings.** Every commit that adds UI text must also update `.pot`/`.po` files.
- **Dark mode always paired:** `text-zinc-900 dark:text-zinc-100`, `bg-zinc-50 dark:bg-zinc-800`.
- **Wishlisted items get dimmed styling:** `opacity-60 hover:opacity-100 transition-opacity`.
- **Icons inside buttons use the `icon` class** instead of explicit size classes (`h-5 w-5`, `size-3.5`, etc.). The `icon` class is provided by Fluxon and auto-sizes icons based on the button's `size` prop.
- **Artist name display uses the MusicBrainz `joinphrase` field** — never join artist names with a literal `", "`.
- **Charts use CSS Grid and responsive HTML**, not SVG.

## Routes / Navigation

- **Three routes per resource with show modals:** `:show`, `:edit` (at `/show/edit`), `:add_*` (at `/show/add-*`).
- **Modals close via `JS.patch`** back to the base route.
- **Search state in URL query params** via `push_patch`.
- **Filter empty params from URLs:** `Enum.filter(fn {_, v} -> v not in ["", nil] end)`.
- **Conditional links based on `purchased_at`:** determines `/collection/` vs `/wishlist/` paths.
- **`/dev/` namespace is for developer tooling only** (LiveDashboard, Oban Web, ErrorTracker). User-facing admin routes belong in the main authenticated `live_session`.

## Database

- **SQLite JSON patterns:** `json_each()` and `json_extract()` via `fragment` for JSON column queries. Expression-based indexes on `json_extract` for performance.
- **Match `GROUP BY` expressions to existing expression indexes.** SQLite treats `json_extract(?, '$.path')` and `? ->> '$.path'` as semantically equal but textually distinct. Use `json_extract` in `fragment` when an expression index on `json_extract(...)` already exists, so the GROUP BY can use the index for natural ordering.
- **Force subquery materialization with `limit: -1` to prevent flattening.** When a date-filtered scan feeds an outer `GROUP BY` and SQLite prefers the wrong composite index, wrap the filter in `subquery()` with `limit: -1`. The forced materialization preserves the range-scan index.
- **Correlated scalar subqueries beat `LEFT JOIN` for small-LIMIT enrichment.** When attaching lookups from a large table to a LIMIT'd result set, inline `(SELECT ... WHERE ...)` in the outer SELECT. Cost then scales with the outer LIMIT, not the lookup table size.
- **Materialized views via triggers** (SQLite lacks native materialized views). Use explicit `up`/`down` in migrations for non-reversible DDL.
- **Read-only schemas** for materialized/view tables: `@primary_key false`, no changeset functions, no timestamps.
- **Every `execute` provides both up and down SQL.** Every index has a comment explaining which query it helps.
- **Config-driven constants.** Pagination defaults and similar magic numbers live in `config/config.exs`, read via `Application.compile_env!/2` into module attributes.

## Error Handling

- **Toast notifications:** `put_toast/3` (arity 3) in LiveViews, `put_toast!/2` (arity 2) in LiveComponents. `:info` for success, `:error` for failures.
- **User-facing error reasons use `ErrorMessages.friendly_message/1`** — never `inspect(reason)`. Call sites keep their contextual prefix (e.g. `gettext("Error refreshing cover")`) and append `": " <> ErrorMessages.friendly_message(reason)` for the reason part. `Logger.error` calls keep `inspect` for debugging.
- **`handle_async` always handles three cases:** `{:ok, {:ok, result}}`, `{:ok, {:error, reason}}`, and `{:exit, reason}`.
- **Data cascade on upstream changes:** When artist metadata changes, regenerate dependent record embeddings.
- **Non-actionable errors use `ErrorTracker.Ignorer`** behaviour to filter (e.g., NoRouteError from bot scanners) rather than blocking paths in the endpoint.
- **Muted errors skip notifications.** `ErrorTracker.ErrorNotifier` checks the `muted` flag before sending email notifications.
- **Oban worker return values follow three states:** `:ok` for success; `{:error, reason}` for transient/retryable failures (Oban will retry); `{:cancel, reason}` (not the deprecated `{:discard, reason}`) for permanent termination when the job outcome is non-retryable (e.g., no Wikipedia entry exists).
- **API failures flow through per-API `ErrorResponse` structs.** Each external API has a `<API>.API.ErrorResponse` struct implementing the `MusicLibrary.ErrorResponse` behaviour (`retryable?/1`, `retry_delay_seconds/1`). Workers match app-layer atom-cancel reasons first (e.g. `:no_english_wikipedia`, `:cover_not_available`), then forward the remaining `{:error, _}` to `MusicLibrary.Worker.ErrorHandler.to_oban_result/1`, which emits `{:snooze, seconds}` for transient errors and `{:cancel, reason}` for permanent ones.
- **Non-fatal enrichment failures are best-effort.** Context functions that enrich records (colors, embeddings) use a private `best_effort_*` helper that logs a warning and returns the unchanged struct rather than surfacing `{:error, reason}` to callers. Business-logic failures (e.g., API calls in `populate_genres/1`) still return `{:error, reason}`.

## Testing

- **Feature-specific test setup stays in the test modules that need it**, not in shared case templates (DataCase, ConnCase). Only add to shared templates when every test using that template genuinely needs it.
- **`@tag :logged_out`** for public endpoint tests. **`@tag :capture_log`** on tests with expected error log output.
- **Fixture modules** use `System.unique_integer([:positive])` for unique names and call through context functions (not raw `Repo.insert`).
- **Verify outcomes through context modules**, not just UI assertions. Delete tests assert both `refute has_element?` and `assert_raise Ecto.NoResultsError`.
- **`render_hook/3`** for testing JS hook interactions.
- Avoid starting test descriptions with "it".
- **No boilerplate-only tests.** Do not add test files that just verify Phoenix generator output (e.g., error view literal strings). Tests must exercise application behaviour.
- **Assert specific values, not just shape.** Prefer `assert data == expected` or `assert data["name"] == "Steven Wilson"` over `assert data != nil` or `assert {:ok, _} = result`. Wildcard matches (`_`) in assertions are a signal the test is too vague.
- **Worker tests that enqueue jobs must `assert_enqueued`.** `perform_job` returning `{:ok, []}` is not sufficient — verify the expected downstream workers were enqueued with correct args.
- **Do not test the same guard at every call site.** If a shared check (e.g., session key presence) is enforced in one place, test it once. Do not duplicate the same assertion across every function that calls the shared check.
- **Consolidate identical assertions across endpoints.** When multiple routes share the same plug/middleware behaviour (e.g., auth), test it once with a loop or parameterised approach, not N separate identical tests.
- **Error assertions must match the error type.** `assert {:error, _reason}` is too broad — match the specific error struct or atom (e.g., `%Req.TransportError{reason: :timeout}`, `:no_session_key`).
- **Do not test untestable operations.** If a database operation (e.g., VACUUM) cannot run in the test sandbox, do not write a test that asserts the sandbox error message. Delete or skip it.
- **Email tests use `Swoosh.Adapters.Sandbox`**, not `Swoosh.Adapters.Test`. Each test setup calls `SwooshSandbox.checkout()` and `SwooshSandbox.checkin()` on exit. When the mailer is invoked from a separate process (e.g., a GenServer started in the test), call `SwooshSandbox.allow(self(), pid)` to share the sandbox with that process.

## Tech Debt / Hygiene

- **Clean up first, then enforce.** Remove all violations before enabling a lint rule.
- **Reverts are total.** Remove every trace: source, CSS, npm deps, config.
- **Never leak sensitive data in prod.** `show_sensitive_data_on_connection_error: false`.
- **Commits are small and single-purpose.** One logical change per commit.
- **Unused aliases are removed** when their module is no longer referenced. Aliases stay alphabetically sorted.
- **Alias nested modules at the top** rather than referencing them inline (e.g. `alias LastFm.Fixtures.RecentTracks` then `RecentTracks.get()`, not `LastFm.Fixtures.RecentTracks.get()`). Enforced by Credo's `AliasUsage` check.
- **Markdown sanitization via MDEx (ammonia).** Use `Markdown.to_html/1` for user content. Annotate raw output with `# sobelow_skip ["XSS.Raw"]` and a comment explaining the sanitization.
- **Sobelow runs on CI and pre-commit** in skip mode for security analysis.
- **`mix deps.audit` runs on CI and pre-commit** (warn-only) via `mix_audit` for CVE scanning.
- **ExSlop checks run via Credo** for code quality: no narrator/boilerplate docs (use `@moduledoc false` instead), no obvious/step/narrator comments, no identity `case`/`with` patterns, no `Repo.all` then filter, no `Enum.map` with inline queries, no unaliased nested module use (nested modules must be aliased at the top). Violations are caught by CI.
- **All modules require `@moduledoc`.** The Credo `ModuleDoc` check is enforced in strict mode.
- **Dialyzer is enabled via `dialyxir` (dev/test only) with the `:no_opaque` flag.** Specs are required and checked. Opaque type checking is disabled to tolerate third-party opaque types (e.g., `Ecto.Changeset`).
- **Validate Docker builder image before updating versions.** When changing `ELIXIR_VERSION`, `OTP_VERSION`, or `DEBIAN_VERSION` in the Dockerfile, run `mise run dev:validate-docker-image` to confirm the generated `hexpm/elixir` tag exists on Docker Hub and supports both `linux/amd64` and `linux/arm64`.

## Reviews & Audits

- **Trace call sites and adjacent layers before flagging.** Surface pattern matching produces false positives. Before claiming a pattern is a problem, follow the actual code paths through every layer that could mitigate it. If you can't show the problem manifests, drop the finding.
- **Project conventions override generic best practices.** "Explicit timeouts", "deterministic test fixtures", "smaller modules", "async queries on mount" are not universal. Where this project diverges, the divergence is deliberate -- read this file first and treat existing patterns as load-bearing.
- **Search closed issues before producing an audit.** Re-raising a finding previously closed as not-planned wastes time. If there is new evidence, link to the prior issue and explain what changed.
- **No tracking-only issues.** Every issue must propose a concrete action. "X is still the same as last audit" or "monitor this module" is not an issue.
- **Use technical terms precisely.** "Circular dependency", "race condition", "N+1 query" have specific definitions. A→C and B→C is not a circular dependency. If the code does not match the definition, find a different framing or drop the finding.
- **Prefer eliminating invalid states at the type level over runtime validation.** When code validates that two options aren't passed together, the better fix is usually to reshape the API so the invalid combination is unrepresentable.

## JavaScript

- **Factory function pattern** for JS hooks when two hooks share logic.
- **Data attributes** (`data-*`) for HTML-to-JS communication. Hooks read `dataset` and `pushEvent` to the server.
