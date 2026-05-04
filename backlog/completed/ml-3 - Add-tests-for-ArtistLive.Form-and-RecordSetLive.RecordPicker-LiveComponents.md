---
id: ML-3
title: Add tests for ArtistLive.Form and RecordSetLive.RecordPicker LiveComponents
status: Done
assignee: []
created_date: "2026-04-20 08:48"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/180"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-16 · updated 2026-04-19 · closed 2026-04-19_

## Summary

Two LiveComponents with real behaviour have zero dedicated test coverage:

- `MusicLibraryWeb.ArtistLive.Form` — 0 %. Edits artist images, integrates with Brave Image Search.
- `MusicLibraryWeb.RecordSetLive.RecordPicker` — 0 %. Record search + add-to-set flow.

## Evidence

From `mix test --cover` in the 2026-04-16 audit. Neither module has a corresponding file under `test/music_library_web/live/`.

## Fix

Add `Phoenix.LiveViewTest`-based tests (needed because these are LiveComponents with `phx-target={@myself}` per project conventions). At minimum:

- `ArtistLive.Form`:
  - Opens and closes
  - Triggers Brave Search via `Req.Test` stub, displays results
  - Uploads an image
  - Submits with a picked image

- `RecordSetLive.RecordPicker`:
  - Opens, searches, displays results
  - Adds a record to the set
  - Handles empty search and no-results states

Fixture: use existing `MusicLibrary.RecordsFixtures` and `MusicLibrary.ArtistInfoFixtures`.

## Acceptance Criteria

<!-- AC:BEGIN -->

- New test files at `test/music_library_web/live/artist_live/form_test.exs` and `test/music_library_web/live/record_set_live/record_picker_test.exs`
- Both components exercise happy paths and at least one error/empty state
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 New test files at `test/music_library_web/live/artist_live/form_test.exs` and `test/music_library_web/live/record_set_live/record_picker_test.exs`
- [ ] #2 Both components exercise happy paths and at least one error/empty state
<!-- AC:END -->
