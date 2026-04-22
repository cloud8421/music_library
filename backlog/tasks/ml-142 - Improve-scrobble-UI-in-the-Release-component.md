---
id: ML-142
title: Improve scrobble UI in the Release component
status: Done
assignee: []
created_date: '2026-04-20 09:32'
updated_date: '2026-04-22 13:27'
labels:
  - ui
  - scrobble
dependencies: []
references:
  - lib/music_library_web/live/components/release.ex
  - lib/music_library_web/components/scrobble_components.ex
  - backlog/ml-142/mockups.html
  - backlog/ml-142/plan.md
documentation:
  - backlog/ml-142/plan.md
  - backlog/ml-142/mockups.html
priority: medium
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Release component's scrobble interface has several usability gaps that make scrobbling cumbersome, especially for multi-medium releases. This task improves the experience across three areas: custom scrobble time, button visual clarity, and per-medium scrobble access.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The release-sheet header renders a `Finished at` date/time picker that displays 'Now' when unset and an explicit time when set
- [x] #2 The release-sheet header renders a solid-primary `Scrobble release` button that scrobbles the whole release using the picker value or `DateTime.utc_now()` when unset
- [x] #3 The release-sheet header renders a `⋯` overflow menu containing `Print tracklist`, plus `Connect Last.fm` when the session key is missing
- [x] #4 The duplicate top-level `Tracks` master checkbox shown on single-medium releases is removed
- [x] #5 Each medium header renders a soft-primary `Scrobble disc` button that is enabled regardless of cross-medium track selection
- [x] #6 Each medium header renders a `⋯` overflow menu containing `Print tracklist` for that medium
- [x] #7 A sticky bar appears at the bottom of the sheet body whenever `MapSet.size(@selected_tracks) > 0`, showing track count, medium count, aggregate duration, and a `Scrobble selected` button
- [x] #8 The sticky bar is not rendered when no tracks are selected
- [x] #9 `Scrobble selected` scrobbles only the ticked tracks using the picker value or `DateTime.utc_now()` when unset
- [x] #10 Clicking a per-medium `Scrobble disc` submits that medium regardless of selection elsewhere, using the picker value or `DateTime.utc_now()`
- [x] #11 The picker has a reset affordance that clears the value back to 'Now'
- [x] #12 Disabled scrobble buttons are visibly distinct from enabled ones in both light and dark mode (verified in browser)
- [x] #13 On viewports ≤ 380px the header reflows: title row above a second row containing the picker (flex-1) and the `Scrobble release` button; per-medium scrobble collapses to icon-only; sticky bar stays legible
- [x] #14 `ScrobbleLive.Show` per-medium scrobble handler works with tracks selected (regression test)
- [x] #15 All new user-facing strings wrapped in gettext; `.pot`/`.po` files regenerated via `mix gettext.extract --merge`
- [x] #16 New LiveComponent tests cover: default picker state, picker value propagating to all three scrobble handlers, sticky-bar rendering, and medium-button enabled-with-selection
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implementation complete 2026-04-22.

Changes:
- `lib/music_library_web/components/release.ex` — header restructure (title + subtitle + picker + solid `Scrobble release` + ⋯ dropdown), `.medium/1` updated (removed selection-blocks-medium disable, label visible, print moved to ⋯ dropdown), new `.selection_bar/1` function component + private `selected_tracks_summary/2` helper, `finished_at` wired into the form via `parse_finished_at/1`, new `clear_finished_at` event handler, and all three scrobble handlers now resolve `socket.assigns.finished_at || DateTime.utc_now()` at call time.
- `test/music_library_web/live/collection_live/show_test.exs` — updated assertion from "Connect your Last.fm account" to new "Connect Last.fm" link label.
- `test/music_library_web/live/scrobble_live/show_test.exs` — regression test added: medium scrobble works with a cross-medium track selected.
- `test/music_library_web/components/release_test.exs` — new file, 10 integration tests through `CollectionLive.Show` covering picker defaults, picker → handler arg propagation, reset-to-now, sticky bar render, cross-medium copy, and scrobble-selected using the picker value.
- `priv/gettext/default.pot` + `priv/gettext/en/LC_MESSAGES/default.po` — regenerated via `mix gettext.extract --merge`.

Verification:
- `mise run dev:precommit` — all green (credo, sobelow, formatting, translations, 823 tests passing).
- Browser-verified at :4003: desktop 1440px (4-disc release showed new header, per-medium buttons, sticky bar with cross-medium count), mobile 360px (header stacks to title + picker + Release button, medium scrobble collapses to icon-only), picker open/select/reset cycle worked, overflow menus rendered Print tracklist.
- `grep -n "MapSet.size(@selected_tracks) > 0" lib/music_library_web/components/release.ex` returns only the sticky-bar visibility guard, as planned.
<!-- SECTION:NOTES:END -->
