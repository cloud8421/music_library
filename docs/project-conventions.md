# Project Conventions

Rules extracted from commit history that are specific to this project and not already covered by `CLAUDE.md` usage rules.

## Commit Messages

- Imperative present tense, single-line, under 60 characters
- Describe intent/behavior, not implementation details
- Reverts use `Revert "Original message"` convention
- NEVER ADD a co-authored by reference in the message body
- If you're working on a GitHub issue, make sure to include the issue ID in the commit message body. Specifies if the commit closes the issue.

## Architecture

- **Context modules own all queries.** LiveViews never query the database directly -- they call context functions.
- **Schemas hold pure accessor/helper functions** on the struct (e.g., `RecordSet.count_by_status/1`). No side effects in schemas.
- **LiveView standard structure:** `mount/3` sets `@current_section`, `handle_params/3` loads data and sets `@page_title` (via pattern-matched private `page_title/2`), `handle_info/2` receives LiveComponent messages.
- **LiveComponents communicate with parent** via `send(self(), {__MODULE__, msg})`.
- **Function components go in domain-specific modules:** `CoreComponents` for generic UI, `RecordComponents` for records, `ScrobbleComponents` for scrobbles, `SearchComponents` for search.
- **External API integrations** follow a three-module pattern: Facade (public API), API (Req HTTP client), Config (NimbleOptions).
- **Oban workers are thin wrappers** that delegate to context modules. `perform/1` should be minimal.
- **Shared utilities** live at parent namespace level (`MusicLibrary.Batch`, not `MusicLibrary.Records.Batch`).

## Extraction / Refactoring

- Extract when duplicated 3+ times. Identical template markup in 3+ places becomes a function component.
- Delete thin wrapper modules with a single caller -- inline them instead.
- Parameterize the differences when extracting shared logic.
- Private helpers go at module bottom, public functions first.

## Template / UI

- **Gettext wraps ALL user-facing strings.** Every commit that adds UI text must also update `.pot`/`.po` files.
- **Dark mode always paired:** `text-zinc-900 dark:text-zinc-100`, `bg-zinc-50 dark:bg-zinc-800`.
- **Wishlisted items get dimmed styling:** `opacity-60 hover:opacity-100 transition-opacity`.

## Routes / Navigation

- **Three routes per resource with show modals:** `:show`, `:edit` (at `/show/edit`), `:add_*` (at `/show/add-*`).
- **Modals close via `JS.patch`** back to the base route.
- **Search state in URL query params** via `push_patch`.
- **Filter empty params from URLs:** `Enum.filter(fn {_, v} -> v not in ["", nil] end)`.
- **Conditional links based on `purchased_at`:** determines `/collection/` vs `/wishlist/` paths.

## Database

- **SQLite JSON patterns:** `json_each()` and `json_extract()` via `fragment` for JSON column queries. Expression-based indexes on `json_extract` for performance.
- **Materialized views via triggers** (SQLite lacks native materialized views). Use explicit `up`/`down` in migrations for non-reversible DDL.
- **Read-only schemas** for materialized/view tables: `@primary_key false`, no changeset functions, no timestamps.
- **Every `execute` provides both up and down SQL.** Every index has a comment explaining which query it helps.
- **Config-driven constants.** Pagination defaults and similar magic numbers live in `config/config.exs`, read via `Application.compile_env!/2` into module attributes.

## Error Handling

- **Toast notifications:** `put_toast/3` (arity 3) in LiveViews, `put_toast!/2` (arity 2) in LiveComponents. `:info` for success, `:error` for failures.
- **User-facing error reasons use `ErrorMessages.friendly_message/1`** — never `inspect(reason)`. Call sites keep their contextual prefix (e.g. `gettext("Error refreshing cover")`) and append `": " <> ErrorMessages.friendly_message(reason)` for the reason part. `Logger.error` calls keep `inspect` for debugging.
- **`handle_async` always handles three cases:** `{:ok, {:ok, result}}`, `{:ok, {:error, reason}}`, and `{:exit, reason}`.
- **Data cascade on upstream changes:** When artist metadata changes, regenerate dependent record embeddings.

## Testing

- **`@tag :logged_out`** for public endpoint tests. **`@tag :capture_log`** on tests with expected error log output.
- **Fixture modules** use `System.unique_integer([:positive])` for unique names and call through context functions (not raw `Repo.insert`).
- **Verify outcomes through context modules**, not just UI assertions. Delete tests assert both `refute has_element?` and `assert_raise Ecto.NoResultsError`.
- **`render_hook/3`** for testing JS hook interactions.

## Tech Debt / Hygiene

- **Clean up first, then enforce.** Remove all violations before enabling a lint rule.
- **Reverts are total.** Remove every trace: source, CSS, npm deps, config.
- **Never leak sensitive data in prod.** `show_sensitive_data_on_connection_error: false`.
- **Commits are small and single-purpose.** One logical change per commit.
- **Unused aliases are removed** when their module is no longer referenced. Aliases stay alphabetically sorted.

## JavaScript

- **Factory function pattern** for JS hooks when two hooks share logic.
- **Data attributes** (`data-*`) for HTML-to-JS communication. Hooks read `dataset` and `pushEvent` to the server.
