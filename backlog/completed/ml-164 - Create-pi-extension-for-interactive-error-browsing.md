---
id: ML-164
title: Create pi extension for interactive error browsing
status: Done
assignee: []
created_date: "2026-05-04 08:08"
updated_date: "2026-05-04 12:44"
labels:
  - pi
  - ready
dependencies: []
modified_files:
  - .pi/extensions/prod-errors/index.ts
  - .pi/extensions/prod-errors/package.json
  - docs/production-infrastructure.md
parent_task_id: ML-161
priority: medium
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Build a pi extension that provides an interactive TUI for browsing production errors, using the `fetch_production_errors` and `fetch_production_error` tools from the parent task.

This extension gives the user (and LLM) a browseable interface for production errors, accessible via a slash command like `/prod-errors`.

### Extension features

1. **`/prod-errors` command** — Opens an interactive TUI using `ctx.ui.custom()`:
   - Lists recent errors (unresolved first, then by last_occurrence_at desc)
   - Shows key metadata: reason (truncated), kind, source location, occurrence count, last seen, status badge, muted indicator
   - Keyboard navigation: up/down to select, Enter to view details, Escape to close
   - Filter toggle: show/hide resolved, show/hide muted (keyboard shortcuts)
   - Pagination: load more errors as user scrolls

2. **Error detail view** (Enter on an error):
   - Full reason text
   - Source location with link-like formatting
   - Status, muted, fingerprint
   - Timeline of occurrences with timestamps
   - Stacktrace display (collapsible per occurrence)
   - Context display (request path, LiveView, etc.)
   - Breadcrumbs if present

3. **UI patterns** (consistent with existing `/prod-logs` extension):
   - Uses `pi.exec("curl", ...)` to call the API
   - Reads credentials from `resolveVar()` (same pattern as prod-logs)
   - Keyboard shortcuts displayed as hints
   - Theme-aware rendering via `ctx.ui.theme`

### TUI component design

```
╔══════════════════════════════════════════════════╗
║ Production Errors                    [12 errors] ║
╠══════════════════════════════════════════════════╣
║ ▶ [UNRESOLVED] FunctionClauseError               ║
║   MusicLibrary.Foo.bar/2  lib/foo.ex:42          ║
║   23 occurrences · last seen 2h ago              ║
║ ──────────────────────────────────────────────── ║
║   [RESOLVED]   MatchError                          ║
║   MusicLibrary.Baz.qux/1  lib/baz.ex:15          ║
║   5 occurrences · last seen 3d ago               ║
║ ──────────────────────────────────────────────── ║
║   [MUTED]      KeyError (key :foo not found)     ║
║   MusicLibrary.Other.func/3  lib/other.ex:99     ║
║   1 occurrence · last seen 7d ago                ║
║ ──────────────────────────────────────────────── ║
║                                                  ║
║  ↑↓ navigate  ↵ details  r toggle resolved      ║
║  m toggle muted  q quit                          ║
╚══════════════════════════════════════════════════╝
```

### File location

`.pi/extensions/prod-errors/index.ts` (new extension, separate from `prod-logs`)

The prod-logs extension already provides the `resolveVar` pattern and `fetchLogs` function. This extension follows the same conventions but for error_tracker data.

<!-- SECTION:DESCRIPTION:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan

### Objective alignment

Build a pi extension (`.pi/extensions/prod-errors/index.ts`) that provides an interactive TUI for browsing production errors, accessible via `/prod-errors`. The extension calls the ML-162 JSON API endpoints (`GET /api/v1/errors` for list, `GET /api/v1/errors/:id` for detail) using the ML-163 auth pattern (`PI_API_TOKEN` + `PI_SERVICE_FQDN_WEB`). The TUI follows the same interactive-component conventions as the existing `prod-logs` extension.

**Dependency chain**: ML-161 → ML-162 (API endpoint) → ML-163 (pi tools for LLM) → ML-164 (interactive TUI). ML-162 must be deployed first. ML-163 is NOT a hard dependency — the TUI calls the API directly (not through pi tools), giving it access to raw JSON with nested occurrences.

### Data shape contract with ML-162

Key fields used by the list view: `id`, `kind`, `reason`, `source_line`, `source_function`, `status`, `muted`, `last_occurrence_at`, `occurrence_count` (see note). **`occurrence_count` gap**: ML-162's current plan omits this from the list endpoint. **Recommendation**: ML-162 should include it via `LEFT JOIN + GROUP BY`. If not, the TUI gracefully omits the count line and shows only the relative timestamp.

### Alternatives considered

1. **Build TUI using pi tools** — Rejected. Tools format/truncate text for LLM; the TUI needs structured JSON for interactive rendering.
2. **Merge into prod-logs extension** — Rejected. Already 550 lines; mixing unrelated concerns bloats the file.
3. **Use `pi.exec("curl")` instead of `fetch()`** — Rejected. `fetch()` provides abort support and JSON parsing. The prod-logs extension uses `fetch()`; the task description's mention of curl is outdated.
4. **Collapsible stacktraces** — Deferred to follow-up. Adds complexity; initial version shows all stacktraces inline.
5. **Auto-load on scroll-to-bottom** — Deferred. No scroll events in `handleInput()`; explicit `l` key is simpler and gives user control.
6. **Relative time display** — Included. Simple arithmetic: "just now" / "Xm ago" / "Xh ago" / "Xd ago".

### Architecture impact analysis

| Touchpoint                                           | Impact                                                                         |
| ---------------------------------------------------- | ------------------------------------------------------------------------------ |
| `.pi/extensions/prod-errors/index.ts`                | **New file** — ~400 lines: `ErrorBrowser` class, helpers, command registration |
| `.pi/extensions/prod-errors/package.json`            | **New file** — minimal `{ name, private, description }`                        |
| `.pi/extensions/prod-logs/index.ts`                  | **No change**                                                                  |
| All Elixir modules, router, PubSub, supervision tree | **No change** — purely a pi extension                                          |
| Pi env vars                                          | Reuses `PI_API_TOKEN` and `PI_SERVICE_FQDN_WEB` from ML-163                    |
| Existing pi extensions                               | **No change** — `/prod-errors` is a new command                                |

### Performance profile

- **List fetch**: One `GET /api/v1/errors` per page/filter change. ~5-20KB response, ~50-150 rendered lines.
- **Detail fetch**: One `GET /api/v1/errors/:id` per Enter. Up to ~500KB for noisy errors with many occurrences.
- **N+1 risk**: None. Only one detail fetch at a time per Enter press.
- **Memory**: JSON + rendered cache bounded by single-page or single-detail data. Caches invalidated on width/state change.
- **Rendering**: O(lines) per frame. Render caching avoids recomputation on unchanged state.
- **Abort support**: In-flight requests aborted before new ones start (filter toggles, load more, detail fetch).

### Benchmarking requirements

No dedicated benchmarks. Thin HTTP client with fixed-size rendering. Server-side API (ML-162) is the bottleneck. If detail view is slow for 100+ occurrences, future optimization: cap displayed occurrences at 50 with a note.

### Cost profile

No paid resources. Makes HTTP requests to the project's own server. No third-party APIs, no additional compute/storage.

### Implementation steps (sequential order)

**Prerequisites**: ML-162 complete; `PI_API_TOKEN` and `PI_SERVICE_FQDN_WEB` configured.

---

#### Step 1: Create `.pi/extensions/prod-errors/package.json`

Minimal `package.json` matching the prod-logs pattern:

```json
{
  "name": "prod-errors",
  "private": true,
  "description": "Interactive TUI for browsing production errors"
}
```

**Verification**: `ls -la .pi/extensions/prod-errors/package.json` — file must exist with valid JSON.

---

#### Step 2: Create the extension skeleton — types, helpers, HTTP functions

Create `.pi/extensions/prod-errors/index.ts` with:

1. **Imports**: `ExtensionAPI` from `@mariozechner/pi-coding-agent`; `matchesKey`, `Key`, `truncateToWidth` from `@mariozechner/pi-tui`; `BorderedLoader` from `@mariozechner/pi-coding-agent`.

2. **TypeScript interfaces** for API responses (matching ML-162 JSON shapes): `ErrorListItem`, `ErrorsListResponse`, `StacktraceLine`, `Occurrence`, `ErrorDetail`. Full interface definitions in the implementation notes.

3. **`Theme` interface**: `{ fg(color: string, text: string): string; bold(text: string): string }` — same as prod-logs.

4. **`resolveVar(name: string): string | undefined`** — identical to prod-logs helper.

5. **`formatRelativeTime(iso8601: string): string`** — seconds diff from `Date.now()`, format as "just now" / "Xm ago" / "Xh ago" / "Xd ago".

6. **`truncateReason(reason: string, maxLen: number): string`** — truncate to maxLen, append "...", take only first line.

7. **`fetchErrors(params, signal?): Promise<ErrorsListResponse>`** — `GET {base}/api/v1/errors` with query params (`status`, `muted`, `search`, `limit`, `offset`). Bearer auth. Throws on non-2xx or JSON parse failure.

8. **`fetchErrorDetail(id, signal?): Promise<ErrorDetail>`** — `GET {base}/api/v1/errors/:id`. Same auth. Throws on non-2xx (including 404) or JSON parse failure.

**Verification**: Use `/reload` and the pi eval REPL to smoke-test helpers in isolation before wiring into the TUI:

1. `formatRelativeTime(new Date(Date.now() - 3600000).toISOString())` → "1h ago"
2. `formatRelativeTime(new Date().toISOString())` → "just now"
3. `truncateReason("very long error message...", 30)` → truncated with "…"
4. Call `fetchErrors({ limit: 1 })` against a running local Phoenix server with seeded data → verify JSON shape matches `ErrorsListResponse`
5. Call `fetchErrorDetail(1)` → verify JSON shape matches `ErrorDetail`

---

#### Step 3: Implement the `ErrorBrowser` class — list view

A class managing list view state and rendering, following the `LogViewer` pattern from prod-logs. State includes: `mode` ("list"/"detail"/"loading"), `errors[]`, `total`, `offset`, `limit` (50), `showResolved`, `showMuted`, `cursorIndex`, `scrollOffset`, `selectedError?`, `detailScrollOffset`, `loadingText`. Callbacks: `onClose`, `onFetchErrors`, `onFetchErrorDetail`.

**List-mode keyboard shortcuts**: ↑/k ↓/j navigate cursor, PgUp/PgDn page, Home/g top, End/G bottom, Enter → detail fetch, `r` toggle resolved, `m` toggle muted, `l` load more, Escape/q close.

**List rendering**: Each error renders as 3 lines (cursor indicator `▶`/`  `, status badge colored via theme, kind, truncated reason; `  {function}  {source_line}`; `  last seen {relative}` with optional `{count} occurrences ·` prefix). Cursor line: `theme.fg("accent")`. Unresolved badge: `theme.fg("error")`. Resolved badge: `theme.fg("success")`. Muted: `theme.fg("muted")`. Separators: `theme.fg("dim")`. Header/footer borders: `theme.fg("accent")`. Keyboard hints: `theme.fg("dim")`.

**Clamping/viewport**: Same as `LogViewer` — `clampCursor()`, `clampViewport()`, `visibleHeight` computed from `process.stdout.rows - chromeHeight` (~8 lines for chrome).

**Caching**: Cache rendered lines when `width` and state unchanged. Invalidate on any state mutation.

**Verification** (requires ML-162 API running locally):

1. `/reload` → `/prod-errors` → TUI opens with error list (or empty state).
2. `j`/`k` moves cursor. `r` toggles resolved. `m` toggles muted. `l` loads next page.
3. `Enter` triggers detail fetch. `q`/`Escape` closes TUI.
4. Missing `PI_API_TOKEN` → clear error notification.

---

#### Step 4: Implement the detail view

Extend `ErrorBrowser` with detail rendering. On Enter in list: set `mode = "loading"`, fetch error detail, on success set `mode = "detail"`, on failure notify and return to list.

**Detail-mode keyboard shortcuts**: Escape → back to list. ↑/k ↓/j scroll, PgUp/PgDn page, Home/g/End/G jump, Enter copies current line to editor.

**Detail rendering**: Build content array with sections (Reason, Status, Source, Fingerprint, First/Last occurrence, Total occurrences), then occurrences section with numbered entries each showing `inserted_at`, reason, context (key: value pairs), breadcrumbs (bullet list), stacktrace (`{app} / {module}.{function}/{arity}  {file}:{line}`). Slice by `detailScrollOffset`. Omit sections when data is empty (`{}` context, `[]` breadcrumbs, zero occurrences → "No occurrences recorded").

**Loading state**: Inline "Loading…" overlay centered in viewport when `mode === "loading"`.

**Verification**:

1. Enter on error → detail shows all sections + occurrences with stacktraces.
2. `j`/`k` scrolls detail. `PgUp`/`PgDn` pages. `Escape` returns to list with cursor preserved.
3. Enter on detail line → line copied to editor (prod-logs pattern).
4. Error with no occurrences → "No occurrences recorded". Empty context/breadcrumbs → sections omitted.

---

#### Step 5: Register the `/prod-errors` command

Register via `pi.registerCommand("prod-errors", ...)`. Handler flow:

1. Validate `PI_SERVICE_FQDN_WEB` and `PI_API_TOKEN` — notify and return if missing.
2. Show `BorderedLoader` while calling `fetchErrors({ limit: 50, offset: 0 })`.
3. On null/empty: notify and return.
4. Show `ErrorBrowser` via `ctx.ui.custom()` — wire up callbacks, handle re-renders.
5. On close: notify "Error browser closed".

In-browser fetches (filter toggles, load more, detail) use an inline loading indicator, not nested `BorderedLoader`.

**Verification**:

1. `/prod-errors` → loader → browser. Toggle filters → inline loading. Load more → inline loading. Detail → inline loading.
2. Bad `PI_SERVICE_FQDN_WEB` → useful error notification. All keyboard shortcuts work.

---

#### Step 6: Edge cases and error handling

| Scenario                                   | Handling                                                                                                                                                 |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Empty list (API returned zero errors)      | "No production errors found" in TUI                                                                                                                      |
| All errors filtered out by current toggles | "No errors match the current filters" (only shown when the unfiltered list was non-empty; track with a `totalUnfiltered` field set on the initial fetch) |
| API non-2xx                                | Error notification with status code; keep TUI open                                                                                                       |
| Unexpected JSON shape                      | Catch TypeError, "Unexpected API response format" notification                                                                                           |
| Network timeout/refused                    | Catch fetch error, show notification                                                                                                                     |
| Double Enter while loading                 | Ignore (`mode === "loading"` guard)                                                                                                                      |
| Rapid filter toggles                       | Abort in-flight request via AbortController before new fetch                                                                                             |
| Filter changes invalidate pages            | Reset offset to 0, replace errors with first page                                                                                                        |
| Load more at end                           | Show "— end of results —", ignore `l`                                                                                                                    |
| Zero occurrences                           | "No occurrences recorded"                                                                                                                                |
| Empty context/breadcrumbs                  | Omit those sections                                                                                                                                      |
| Missing stacktrace fields                  | Show "—"                                                                                                                                                 |
| Narrow terminal (< 40 cols)                | Render with heavy truncation (acceptable)                                                                                                                |

**Abort pattern**: Store `currentAbortController` reference; call `.abort()` before each new fetch; catch `AbortError` and return null.

**Verification**:

1. **Rapid filter toggle**: Press `r` 5 times rapidly → observe only the last fetch's results are displayed (previous requests were aborted). Requests aborted via `AbortController` should not update state.
2. **End-of-results**: Navigate to the last page with `l`, then press `l` again → observe "— end of results —" divider and subsequent `l` presses are ignored.
3. **Empty context/breadcrumbs**: View a detail for an error that has occurrences with `context: {}` and `breadcrumbs: []` → observe those section headings are entirely omitted from the detail rendering.
4. **Network error**: Set `PI_SERVICE_FQDN_WEB` to `http://localhost:9999` (unreachable port) and open `/prod-errors` → observe a clear network error notification and the TUI does not crash.
5. **Filters exclude everything**: Start with a list that has errors, set both `showResolved=false` and `showMuted=false`, then resolve and mute every error in the database via the ErrorTracker dashboard. Re-open `/prod-errors` → observe "No errors match the current filters" (not "No production errors found").
6. **No errors at all**: Truncate the error_tracker tables and open `/prod-errors` → observe "No production errors found".

---

#### Step 7: Integration verification (end-to-end)

Seed 15+ errors with varied statuses and 3+ occurrences each. Use the ML-162 error fixtures from `test/support/fixtures/errors_fixtures.ex` — insert error and occurrence records via `MusicLibrary.Repo` with `ErrorTracker.Error` and `ErrorTracker.Occurrence` structs (see ML-162's "Test data seeding strategy" for the exact insertion pattern, including the `fingerprint` hex-string encoding and `Stacktrace` struct construction). Ensure at least: 5 unresolved, 5 resolved, 2 muted, 2 with no occurrences, 1 with 10+ occurrences for scroll testing.

Full walkthrough: list rendering, status badges, muted indicator, relative timestamps, filter toggles, detail view with occurrences/stacktraces/context/breadcrumbs, copy-to-editor, Escape back to list, `q` close. Verify that after ML-162 is deployed and `occurrence_count` is available in the list endpoint, the count line appears in the list view. Run `mix test` for no Elixir regressions.

### Production Changes

No new changes beyond ML-162/ML-163: `PI_API_TOKEN` and `PI_SERVICE_FQDN_WEB` are already required.

### Documentation updates

- **`docs/architecture.md`** — Add `prod-errors` pi extension entry (location, purpose, slash command, required env vars).
- **`docs/production-infrastructure.md`** — No changes needed if ML-163 docs are merged. Otherwise include env var entries.
- No changes to `docs/project-conventions.md` or `docs/available-tasks.md`.

### Dependencies

- **ML-162**: Required (API endpoints). Deploy first.
- **ML-163**: Not hard dependency (TUI calls API directly), but defines auth pattern.
- `@mariozechner/pi-coding-agent` and `@mariozechner/pi-tui`: Already available.
- No new npm dependencies.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Implementation Notes

### What was built

Added the `/prod-errors` interactive TUI command to the existing `.pi/extensions/prod-errors/` extension (which already contained the `fetch_production_errors` and `fetch_production_error` LLM tools from ML-163).

### Files changed

- `.pi/extensions/prod-errors/index.ts` — Added ErrorBrowser class (~540 lines), Theme interface, formatRelativeTime/truncateReason helpers, and `/prod-errors` command registration. Total file grew from ~360 to ~1396 lines.
- `.pi/extensions/prod-errors/package.json` — Updated description to mention TUI command.
- `docs/production-infrastructure.md` — Added `/prod-errors` to the pi coding agent tools table and added command description.

### Key design decisions

1. **Reuses existing HTTP functions** — `fetchErrors()` and `fetchError()` from ML-163 are reused directly by the ErrorBrowser class. The class builds URLs via the existing `buildUrl()` helper.
2. **Flat rendering (not Container/Text)** — Follows the prod-logs pattern of building arrays of styled strings, not the component-based approach using Container/Text/Box. This is simpler and directly compatible with the `ctx.ui.custom()` API.
3. **Self-contained class** — ErrorBrowser manages all state, navigation, rendering, and async operations internally. It receives `requestRender` and `notify` callbacks from the command handler for I/O.
4. **Occurrence count omission** — The list endpoint doesn't include `occurrence_count` (per ML-162 spec), so the list view shows relative timestamps instead.
5. **No collapsible stacktraces** — Deferred per implementation plan. Initial version shows all stacktraces inline with scrolling.
6. **Explicit load-more** — No auto-load on scroll-to-bottom. Uses `l` key for user-controlled pagination.
<!-- SECTION:NOTES:END -->
