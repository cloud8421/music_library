---
id: ML-182
title: Analyze and plan elimination of LiveViewTest usage in favor of PhoenixTest
status: To Do
assignee: []
created_date: "2026-05-14 21:40"
updated_date: "2026-05-14 21:41"
labels:
  - testing
  - refactoring
  - analysis
dependencies: []
references:
  - >-
    test/support/conn_case.ex (shows auto-imported LiveViewTest subset and
    PhoenixTest)
documentation:
  - "https://hexdocs.pm/phoenix_test/PhoenixTest.html"
  - "https://hexdocs.pm/phoenix_live_view/Phoenix.LiveViewTest.html"
modified_files:
  - test/music_library_web/components/chat_test.exs
  - test/music_library_web/components/release_test.exs
  - test/music_library_web/live/artist_live/show_test.exs
  - test/music_library_web/live/collection_live/index_test.exs
  - test/music_library_web/live/maintenance_live/index_test.exs
  - test/music_library_web/live/online_store_template_live/index_test.exs
  - test/music_library_web/live/record_set_live/index_test.exs
  - test/music_library_web/live/record_set_live/show_test.exs
  - test/music_library_web/live/scrobble_live/index_test.exs
  - test/music_library_web/live/scrobble_live/release_group_show_test.exs
  - test/music_library_web/live/scrobble_live/release_show_test.exs
  - test/music_library_web/live/scrobble_rules_live/index_test.exs
  - test/music_library_web/live/scrobbled_tracks_live/index_test.exs
  - test/music_library_web/live/scrobbled_tracks_live/rule_picker_test.exs
  - test/music_library_web/live/stats_live/top_albums_test.exs
  - test/music_library_web/live/wishlist_live/index_test.exs
  - test/music_library_web/live_helpers/record_actions_test.exs
priority: medium
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Audit all LiveView and component tests that use LiveViewTest (either exclusively or mixed with PhoenixTest) and determine which can be converted to use only PhoenixTest. The project's ConnCase auto-imports both PhoenixTest (full) and Phoenix.LiveViewTest (subset via `only:`), creating a dual-framework testing situation. The goal is to reduce complexity by eliminating LiveViewTest usage where possible.

An initial analysis of 17 files has been completed. The task is to refine this analysis and produce a concrete migration plan with cost estimates.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 All 17 files are classified as fully eliminable, partially eliminable, or blocked with clear rationale for each
- [ ] #2 Three blocking patterns (send_update/3, send(view.pid), live_isolated) are documented with suggested workarounds
- [ ] #3 A concrete migration order is proposed, prioritizing low-risk fully-eliminable files first
- [ ] #4 Cost estimates (effort level: low/medium/high) are assigned to each file or group of files
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Initial Analysis (completed 2026-05-14)

### Context

`ConnCase` auto-imports both frameworks:

- `PhoenixTest` (full) — provides `visit/2`, `click/2`, `fill_in/2`, `assert_has/3`, `refute_has/3`, `assert_path/2`, `trigger_hook/3`, `upload/2`, `unwrap/2`, etc.
- `Phoenix.LiveViewTest` (subset via `only:`) — provides `render_async/1`, `render_change/2`, `render_click/3`, `render_hook/3`, `element/2`, `form/3`

Files that need `live/2` (not auto-imported) add `import Phoenix.LiveViewTest` explicitly.

### Per-file classification

#### 🟢 Fully eliminable (11 files)

Pattern: `live/2` → `visit/2`, `render_click/3` → `click/2`, `render_submit/1` → `click_button/2`, `render_change/2` → `fill_in/2`, `render/1` → `assert_has/3`, `has_element?/2` → `assert_has/3`/`refute_has/3`, `assert_patch/2` → `assert_path/2`, `page_title/1` → `assert_has("title", text: "...")`

1. `live/artist_live/show_test.exs` — `live/2` for image edit modal; `file_input/3`+`render_upload/3` → PhoenixTest `upload/2`
2. `live/maintenance_live/index_test.exs` — All 11 tests use `live/2`+`render_click/3`. External redirect test needs `assert_redirect/2`.
3. `live/online_store_template_live/index_test.exs` — Mixed `visit/2` and `live/2`. `assert_patch/2`→`assert_path/2`.
4. `live/record_set_live/index_test.exs` — Mixed `visit/2` and `live/2`.
5. `live/record_set_live/show_test.exs` — Mixed. `render_hook/3` has PhoenixTest `trigger_hook/3` equivalent. `assert_redirect/2`→`assert_path/2`.
6. `live/scrobble_live/index_test.exs` — Uses `unwrap/2` bridge pattern, no `live/2`. Drop `unwrap`, use direct PhoenixTest.
7. `live/scrobble_live/release_group_show_test.exs` — One `live/2` for `page_title/1`. Replace with `assert_has("title", ...)`.
8. `live/scrobble_live/release_show_test.exs` — Same page_title pattern.
9. `live/scrobble_rules_live/index_test.exs` — All `live/2`. Standard conversion.
10. `live/scrobbled_tracks_live/index_test.exs` — `unwrap/2` bridge, no `live/2`. Drop `unwrap`.
11. `live/scrobbled_tracks_live/rule_picker_test.exs` — All `live/2`. Standard conversion.
12. `live/stats_live/top_albums_test.exs` — Mixed. `live/2` for cover URL/badge tests.

#### 🟡 Mostly eliminable (4 files)

Blocked by `send(view.pid, message)` pattern for testing internal `handle_info/2` callbacks.

13. `live/collection_live/index_test.exs` — 2 PubSub tests use `send(view.pid, :records_index_changed)`. 3 cart format tests use `live/2` for `render_change/2` with nested params.
14. `live/wishlist_live/index_test.exs` — Same PubSub pattern. Single-item import uses `live/2`.
15. `live_helpers/record_actions_test.exs` — One test uses `send(view.pid, {Chat, :chats_changed})`. Rest are standard `live/2`+`render_click/3`.
16. `components/release_test.exs` — `render_change/2` with nested LiveComponent form data. `ShowPrintTest` sub-module uses `live_isolated/3`.

#### 🔴 Hard to eliminate (1 file)

17. `components/chat_test.exs` — `Phoenix.LiveView.send_update(view.pid, Chat, [chunk: ..., done: ..., error: ...])` drives the Chat component's internal `update/2` callback directly. This is unit-level LiveComponent testing with no PhoenixTest equivalent. 3 tests in "update/2 streaming state transitions" describe block.

### Three blocking patterns

**Pattern 1: `Phoenix.LiveView.send_update/3`** (chat_test.exs)

- Used to test component's `update/2` callback with internal state tuples (`chunk:`, `done:`, `error:`)
- No PhoenixTest equivalent — PhoenixTest has no concept of LiveComponent PIDs
- Workaround: Rewrite as integration tests through the actual SSE streaming pipeline
- Effort: High (rewrite 3 tests with streaming stub setup)

**Pattern 2: `send(view.pid, message)`** (collection_live, wishlist_live, record_actions)

- Used to test `handle_info/2` callbacks for PubSub-driven updates
- PhoenixTest sessions don't expose LiveView PIDs
- Workaround: Trigger the actual side effects (create records, broadcast via PubSub, interact with Chat component) and use `assert_has/3` with timeout
- Effort: Medium per affected test (need to verify PhoenixTest sessions pick up out-of-band PubSub updates)

**Pattern 3: `live_isolated/3`** (components/release_test.exs ShowPrintTest)

- Mounts a LiveComponent in isolation to test a specific assign
- PhoenixTest requires full page navigation
- Workaround: Test through parent LiveView (`/collection/:id`) with `visit/2`
- Effort: Low (2 tests, simple assertion)

### Proposed migration order

1. **Wave 1 (low risk):** Drop `unwrap/2` bridges — `scrobble_live/index_test.exs`, `scrobbled_tracks_live/index_test.exs`
2. **Wave 2 (low risk):** Convert `page_title/1` tests — `scrobble_live/release_group_show_test.exs`, `scrobble_live/release_show_test.exs`
3. **Wave 3 (medium risk):** Convert `live/2` → `visit/2` for standard CRUD LiveViews — `scrobble_rules_live`, `online_store_template_live`, `record_set_live/index`, `record_set_live/show`, `scrobbled_tracks_live/rule_picker`, `maintenance_live`
4. **Wave 4 (medium risk):** Convert mixed-usage files — `artist_live/show`, `stats_live/top_albums`
5. **Wave 5 (higher risk):** Files with `send(view.pid)` blockers — `collection_live/index`, `wishlist_live/index`, `record_actions`, `components/release`
6. **Wave 6 (hardest):** Component streaming tests — `components/chat`

### Cost estimates

| Wave | Effort             | Files                                                                     |
| ---- | ------------------ | ------------------------------------------------------------------------- |
| 1    | Low (30 min)       | 2 files — mechanical removal of `unwrap/2`                                |
| 2    | Low (15 min)       | 2 files — replace `page_title/1`                                          |
| 3    | Medium (2-3h)      | 6 files — `live/2`→`visit/2`, selector adjustments                        |
| 4    | Medium (1-2h)      | 2 files — `file_input/3`+`render_upload/3`→`upload/2`, `live/2`→`visit/2` |
| 5    | Medium-High (3-4h) | 4 files — PubSub workarounds, `live_isolated`→parent page                 |
| 6    | High (4-6h)        | 1 file — rewrite streaming tests as integration tests                     |

<!-- SECTION:NOTES:END -->
