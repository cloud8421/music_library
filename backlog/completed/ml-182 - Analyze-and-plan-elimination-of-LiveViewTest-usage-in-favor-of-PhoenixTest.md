---
id: ML-182
title: Analyze and plan elimination of LiveViewTest usage in favor of PhoenixTest
status: Done
assignee: []
created_date: "2026-05-14 21:40"
updated_date: "2026-05-23 06:17"
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

Audit all LiveView and component tests that mix LiveViewTest and PhoenixTest, and eliminate LiveViewTest usage where possible. The project's ConnCase auto-imports both frameworks, creating unnecessary dual-framework complexity.

The work is broken into 6 waves by difficulty, each tracked as a subtask.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 All 17 files are classified as fully eliminable, partially eliminable, or blocked with clear rationale for each
- [x] #2 Three blocking patterns (send_update/3, send(view.pid), live_isolated) are documented with suggested workarounds
- [x] #3 A concrete migration order is proposed, prioritizing low-risk fully-eliminable files first
- [x] #4 Cost estimates (effort level: low/medium/high) are assigned to each file or group of files

<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Key challenges discovered during execution

1. **PhoenixTest can't click `<span>` elements** (Fluxon `.badge`) — only `<a>` (`click_link`) and `<button>` (`click_button`). HTML changes needed for badge-based interactions.

2. **Fluxon input labels** using `data-part="field"` wrapper without separate visible text labels don't match `fill_in`. Workaround: visit with query params to trigger `handle_params` search.

3. **LiveComponent modals with `phx-target`** don't respond to URL query params — need actual form interaction, which is harder with PhoenixTest when labels are missing.

4. **`trigger_hook` in PhoenixTest** expects JSON-encoded values, not Elixir maps. Different API from LiveViewTest's `render_hook`.

5. **`render_async/1` is auto-imported by ConnCase** — can use `unwrap(&render_async/1)` without any explicit import. This is the only LiveViewTest function that remains needed for async data loading.

<!-- SECTION:NOTES:END -->
