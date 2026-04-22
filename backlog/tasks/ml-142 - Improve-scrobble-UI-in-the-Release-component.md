---
id: ML-142
title: Improve scrobble UI in the Release component
status: In Progress
assignee: []
created_date: '2026-04-20 09:32'
updated_date: '2026-04-22 12:42'
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
- [ ] #1 The release-sheet header renders a `Finished at` date/time picker that displays 'Now' when unset and an explicit time when set
- [ ] #2 The release-sheet header renders a solid-primary `Scrobble release` button that scrobbles the whole release using the picker value or `DateTime.utc_now()` when unset
- [ ] #3 The release-sheet header renders a `⋯` overflow menu containing `Print tracklist`, plus `Connect Last.fm` when the session key is missing
- [ ] #4 The duplicate top-level `Tracks` master checkbox shown on single-medium releases is removed
- [ ] #5 Each medium header renders a soft-primary `Scrobble disc` button that is enabled regardless of cross-medium track selection
- [ ] #6 Each medium header renders a `⋯` overflow menu containing `Print tracklist` for that medium
- [ ] #7 A sticky bar appears at the bottom of the sheet body whenever `MapSet.size(@selected_tracks) > 0`, showing track count, medium count, aggregate duration, and a `Scrobble selected` button
- [ ] #8 The sticky bar is not rendered when no tracks are selected
- [ ] #9 `Scrobble selected` scrobbles only the ticked tracks using the picker value or `DateTime.utc_now()` when unset
- [ ] #10 Clicking a per-medium `Scrobble disc` submits that medium regardless of selection elsewhere, using the picker value or `DateTime.utc_now()`
- [ ] #11 The picker has a reset affordance that clears the value back to 'Now'
- [ ] #12 Disabled scrobble buttons are visibly distinct from enabled ones in both light and dark mode (verified in browser)
- [ ] #13 On viewports ≤ 380px the header reflows: title row above a second row containing the picker (flex-1) and the `Scrobble release` button; per-medium scrobble collapses to icon-only; sticky bar stays legible
- [ ] #14 `ScrobbleLive.Show` per-medium scrobble handler works with tracks selected (regression test)
- [ ] #15 All new user-facing strings wrapped in gettext; `.pot`/`.po` files regenerated via `mix gettext.extract --merge`
- [ ] #16 New LiveComponent tests cover: default picker state, picker value propagating to all three scrobble handlers, sticky-bar rendering, and medium-button enabled-with-selection
<!-- AC:END -->
