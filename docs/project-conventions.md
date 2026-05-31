# Project Conventions

Rules extracted from commit history that are specific to this project and not already covered by `AGENTS.md` usage rules.

## Commit Messages

→ See `.agents/skills/git-commit/SKILL.md` for full conventions, checklist, and examples.

Key rules: imperative present tense, single-line under 60 characters, task ID prefix when the work maps to a Backlog.md task, "Update dependencies" for mix and "Update npm dependencies" for npm, never "Co-Authored-By".

## Workflow

- **Backlog.md is the source of truth for task management.** The project has the Backlog.md MCP server configured; use it (via the MCP tools) for creating, viewing, and updating tasks. Do not invent a parallel tracking system.
- **All work that maps to a Backlog.md task must reference the task identifier in the commit subject** (see Commit Messages above). One commit can reference one task; if a single change spans multiple tasks, that is a signal to split the commit.
- When creating a Backlog.md task, **make sure you fill all task sections of the task**. It's critical you write an implementation plan in the task.
- When working on a Backlog.md task, **make sure to read the implementation plan included in the task, and follow it**. If the plan is outdated compared to the conditions of the codebase, notify the user.
- **GitHub issues are legacy and read-only for the agent.** Never create, comment on, close, or reopen GitHub issues — only the user does that. When asked about "the issue tracker" or "open issues", reach for Backlog.md, not `gh issue`.

### Pre-commit Hooks

The pre-commit hook (`scripts/dev/precommit`) inspects staged files and runs only the checks relevant to the change, rather than always running the full verification suite. CI always runs the full suite unconditionally.

| Category    | File pattern                                                                                                                                 | Checks (conditional)                                                                                                                                                                       |
| ----------- | -------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **elixir**  | `lib/`, `test/`, `config/`, `mix.exs`, `mix.lock`, `priv/repo/migrations/`, `priv/gettext/`, `.credo.exs`, `.formatter.exs`, `.sobelow-conf` | `mix format --check-formatted`<br>`mix credo --strict`<br>`mix sobelow --compact --exit`<br>`mix gettext.extract --check-up-to-date`<br>`mise run //:test`<br>`mix deps.unlock --unused` † |
| **shell**   | `scripts/`, `.shellcheckrc`                                                                                                                  | `shellcheck` on all `scripts/` files (excluding `.hurl`)                                                                                                                                   |
| **assets**  | `assets/`, `.pi/extensions/.*\.(ts\|js\|json)$`                                                                                              | `prettier` on CSS, JS, and TS/JSON in `.pi/extensions/` (excluding `node_modules`)                                                                                                         |
| **docs**    | `docs/`, `README.md`, `AGENTS.md`                                                                                                            | `prettier` on Markdown and Livebook files                                                                                                                                                  |
| **backlog** | `backlog/`                                                                                                                                   | `prettier` on all backlog markdown files                                                                                                                                                   |
| **presto**  | `presto/`                                                                                                                                    | `(cd presto && mise run test)` — runs pytest                                                                                                                                               |
| **docker**  | `Dockerfile`, `.dockerignore`, `compose.yaml`                                                                                                | `mise run dev:validate-docker-image` (only if `Dockerfile` is staged)                                                                                                                      |

> **† `mix deps.unlock --unused` sub-gate**: Runs only when `mix.exs` or `mix.lock` is in the staged files — not on every Elixir change. An unused dependency can only be introduced by changing the dependency specification, not by changing application code.

If no staged files match any category (e.g., `git commit --allow-empty`), the script exits early without running any checks.

## Architecture

- **Context modules own all queries.** LiveViews never query the database directly -- they call context functions.
- **Schemas hold pure accessor/helper functions** on the struct (e.g., `RecordSet.count_by_status/1`). No side effects in schemas.
- **LiveView standard structure:** `mount/3` sets `@current_section`, `handle_params/3` loads data, sets `@page_title` (via pattern-matched private `page_title/2`), and manages PubSub subscriptions via `LiveHelpers.RecordActions.manage_subscription/2` (unsubscribing from the previous record and subscribing to the new one). `handle_info/2` receives LiveComponent messages and validates inbound record updates against `socket.assigns.record.id` to discard stale messages.
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

→ See `.agents/skills/ui-framework/SKILL.md` for full conventions, component patterns, and Fluxon reference.

Key rules: Gettext wraps ALL user-facing strings, dark mode always paired (`text-zinc-900 dark:text-zinc-100`), wishlisted items dimmed (`opacity-60`), icons use `icon` class, artist names use MusicBrainz `joinphrase`, charts use CSS Grid (not SVG).

## Routes / Navigation

→ See `.agents/skills/ui-framework/SKILL.md` for full route patterns.

Key rules: three routes per resource with show modals, modals close via `JS.patch`, search state in URL query params, empty params filtered from URLs, conditional links based on `purchased_at`, `/dev/` namespace for developer tooling only.

## Database

→ See `.agents/skills/sqlite-optimization/SKILL.md` for full query patterns, index rules, FTS5 conventions, and migration requirements.

Key rules: `json_extract()` must match expression index text exactly, subquery materialization via `limit: -1`, correlated scalar subqueries beat `LEFT JOIN` for small-LIMIT enrichment, every migration provides both `up` and `down` SQL, config-driven constants in `config/config.exs`.

## Error Handling

→ See `.agents/skills/error-investigation/SKILL.md` for production error triage, `.agents/skills/external-api-integration/SKILL.md` for ErrorResponse/ErrorHandler patterns, and `.agents/skills/oban-worker/SKILL.md` for worker return values.

- **Toast notifications:** `put_toast/3` (arity 3) in LiveViews, `put_toast!/2` (arity 2) in LiveComponents. `:info` for success, `:error` for failures.
- **User-facing error reasons use `ErrorMessages.friendly_message/1`** — never `inspect(reason)`. Call sites keep their contextual prefix and append `": " <> ErrorMessages.friendly_message(reason)`. `Logger.error` calls keep `inspect` for debugging.
- **`handle_async` always handles three cases:** `{:ok, {:ok, result}}`, `{:ok, {:error, reason}}`, and `{:exit, reason}`.
- **Data cascade on upstream changes:** When artist metadata changes, regenerate dependent record embeddings.
- **Non-fatal enrichment failures are best-effort.** Context functions that enrich records (colors, embeddings) use a private `best_effort_*` helper that logs a warning and returns the unchanged struct. Business-logic failures still return `{:error, reason}`.

## Testing

→ See `.agents/skills/testing/SKILL.md` for full conventions, fixture modules, and SQLite/Swoosh/Worker test patterns.

Key rules: feature setup stays in test modules that need it, fixture modules use `System.unique_integer([:positive])`, LiveView async page tests use `render_async()` from `LiveTestHelpers` rather than `unwrap(&render_async/1)`, assert specific values not just shapes, error assertions match specific error types, worker tests must `assert_enqueued`, no boilerplate-only tests.

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
- **ExSlop and custom Credo checks run via Credo** for code quality: no narrator/boilerplate docs (use `@moduledoc false` instead), no obvious/step/narrator comments, no identity `case`/`with` patterns, no `Repo.all` then filter, no `Enum.map` with inline queries, no unaliased nested module use (nested modules must be aliased at the top), no LiveComponent toast helper misuse (`put_toast!/2` in LiveComponents, `put_toast/3` in LiveViews). Violations are caught by CI.
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
