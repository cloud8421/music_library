---
id: ML-145
title: Restructure /scrobble routes; reuse Release component on scrobble page
status: To Do
assignee: []
created_date: '2026-04-23 06:11'
labels:
  - ui
  - scrobble
  - refactor
  - liveview
dependencies: []
references:
  - lib/music_library_web/components/release.ex
  - lib/music_library_web/live/scrobble_live/index.ex
  - lib/music_library_web/live/scrobble_live/show.ex
  - lib/music_library/records/tracklist_pdf.ex
  - backlog/ml-142/plan.md
  - >-
    backlog/tasks/ml-142.1 -
    Port-Finished-at-picker-and-selection-bar-to-ScrobbleLive.Show.md
documentation:
  - .claude/plans/scrobble-route-restructure/design.md
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
## Why

`/scrobble/:release_id` (`MusicLibraryWeb.ScrobbleLive.Show`) re-implements scrobbling UI that already exists as a LiveComponent used by collection/wishlist show pages (`MusicLibraryWeb.Components.Release`). Today the scrobble page imports `medium/1` and `scrobble_button_label/1` from that component but reimplements `scrobble_release` / `scrobble_medium` / `scrobble_selected_tracks` with hard-coded `DateTime.utc_now/0`, no `Finished at` picker, and no selection bar. ML-142.1 proposed porting those affordances into `ScrobbleLive.Show` in parallel — which would leave two drifting implementations.

This task takes the opposite approach: make the Release LiveComponent reusable outside the sheet (currently tightly coupled to `%Records.Record{}` and wrapped in `<.sheet>`), restructure the scrobble routes into a bookmarkable hierarchy, and delete the custom scrobble UI in favour of reuse.

**Supersedes ML-142.1** — the ML-142.1 ACs become free once the component is reused on the new scrobble page. ML-142.1 can be archived as superseded.

## What

Three routes:

- `/scrobble` — search only. Release-group clicks `<.link navigate>` to `/scrobble/:rg_id` (no more inline release-loading state).
- `/scrobble/:rg_id` (new) — release-group header (cover, title, primary artist, type badge, first-release date, release count) + full list of releases; each release links to `/scrobble/:rg_id/releases/:release_id`.
- `/scrobble/:rg_id/releases/:release_id` (new, replaces `/scrobble/:release_id`) — the scrobble page itself, rendered by the same LiveComponent that powers the collection/wishlist show sheet.

Old `/scrobble/:release_id` → 404 (personal app; bookmark churn is acceptable, not worth 301-redirect plumbing).

## Key refactor decisions (working design doc: `.claude/plans/scrobble-route-restructure/design.md`, local-only)

1. **Release LiveComponent input contract** — takes `release_id` (string) instead of `record`; adds `show_print?: boolean`. Header title/artists derive from the loaded `%MusicBrainz.Release{}`.
2. **`<.sheet>` moves to callsites** — single render path for the component. Collection/wishlist show pages wrap in their own `<.sheet>`; the scrobble release page renders it directly under `<Layouts.app>`.
3. **Selection bar stickiness** — switches to `position: sticky` so it works both inside a sheet (pins to sheet bottom) and on a page (pins to viewport bottom) with single markup, no mode flag.
4. **`TracklistPdf` signatures** — `generate/1` and `generate_medium/2` take a `%MusicBrainz.Release{}`; no `%Records.Record{}` required (both fields used by the PDF — `title` and `artists` — already exist on the release struct).
5. **Module names** — new `MusicLibraryWeb.ScrobbleLive.ReleaseGroupShow` at `/scrobble/:rg_id`; rename `MusicLibraryWeb.ScrobbleLive.Show` → `MusicLibraryWeb.ScrobbleLive.ReleaseShow` at `/scrobble/:rg_id/releases/:release_id`, removing its custom scrobble UI in favour of embedding the LiveComponent.
6. **Unused after refactor** — `MusicLibraryWeb.Components.Release.scrobble_button_label/1` (delete).

## Non-goals

- Scrobble-rule picker on the scrobble page (fresh MB releases have no misrecognised tracks yet).
- Cross-link to `/collection/:id` when the release is already collected.
- 301-redirecting old `/scrobble/:release_id` URLs.
- Breadcrumbs on the scrobble page.
- Preserving `?query=X` across nested URLs (browser back button already works).
- Splitting the Release LiveComponent into separate `Content` / `Sheet` modules.
- Changes to `MusicLibrary.ScrobbleActivity`.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 /scrobble/:rg_id renders a release-group header (cover, release-group title, primary artist, type badge, first-release date, release count) and the full list of releases returned by MusicBrainz for that group.
- [ ] #2 Each release in the /scrobble/:rg_id list is a navigate link to /scrobble/:rg_id/releases/:release_id.
- [ ] #3 /scrobble/:rg_id shows an error toast and redirects to /scrobble if fetching the release group or its releases fails.
- [ ] #4 /scrobble/:rg_id/releases/:release_id renders a scrobble page with picker-driven `Finished at`, release-level scrobble, per-medium scrobble, track-selection + selection-bar scrobble, and Print tracklist — behaviour identical to the collection/wishlist show sheet.
- [ ] #5 /scrobble/:rg_id/releases/:release_id has a `Back to releases` link that navigates to /scrobble/:rg_id.
- [ ] #6 Old /scrobble/:release_id returns 404 (not redirected, not aliased).
- [ ] #7 /scrobble no longer renders releases inline; release-group list items are navigate links to /scrobble/:rg_id. The `?query=X` search param still works as before.
- [ ] #8 The Release LiveComponent on the scrobble page and on the collection/wishlist sheet share a single implementation — there is no parallel reimplementation of scrobble handlers, picker, or selection bar.
- [ ] #9 The selection bar stays visible at the bottom of the visible scroll region in both contexts (scrobble page viewport, collection/wishlist sheet inner scroll) while tracks scroll, using a single markup path.
- [ ] #10 MusicLibrary.Records.TracklistPdf generates tracklist PDFs from a MusicBrainz release struct alone (no Records.Record required). Output for collection/wishlist records is visually unchanged.
- [ ] #11 The Release LiveComponent supports suppressing both the release-level and per-medium Print tracklist dropdown entries via a single input (both hidden together); the suppression state is covered by a component test.
- [ ] #12 MusicLibraryWeb.ScrobbleLive.Show's custom scrobble UI and handlers (scrobble_release, scrobble_medium, scrobble_selected_tracks, validate, recover_form) are deleted. MusicLibraryWeb.Components.Release.scrobble_button_label/1 is deleted as unused.
- [ ] #13 All new user-facing strings are wrapped in gettext; .pot/.po files regenerated via `mix gettext.extract --merge`.
- [ ] #14 Tests updated: test/music_library_web/components/release_test.exs covers the new `release_id` input contract and both states of the print-suppression input; test/music_library/records/tracklist_pdf_test.exs covers the new generate/1 and generate_medium/2 signatures.
- [ ] #15 Tests added: test/music_library_web/live/scrobble_live/release_group_show_test.exs covers happy path (header fields + releases list + link targets) and fetch failure (toast + redirect); test/music_library_web/live/scrobble_live/release_show_test.exs (replacing show_test.exs) smoke-tests mount, component render, and back-link target.
- [ ] #16 Tests updated: test/music_library_web/live/scrobble_live/index_test.exs asserts release-group clicks navigate (no inline state); collection/wishlist show tests updated for the new component input shape and callsite sheet markup.
- [ ] #17 Manual UI verification via `iex -S mix phx.server`: sheet selection-bar still pins correctly on collection/wishlist show pages; page selection-bar pins to viewport bottom on scrobble page while tracks list scrolls; navigation loop /scrobble → /scrobble/:rg_id → /scrobble/:rg_id/releases/:release_id → back → back works, and `?query=X` survives the browser back button.
<!-- AC:END -->
