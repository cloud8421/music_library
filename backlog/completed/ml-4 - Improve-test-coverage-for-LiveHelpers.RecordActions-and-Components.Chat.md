---
id: ML-4
title: Improve test coverage for LiveHelpers.RecordActions and Components.Chat
status: Done
assignee: []
created_date: '2026-04-20 08:48'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/179'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-16 · updated 2026-04-17 · closed 2026-04-17_

## Summary

Two shared/user-facing surfaces have low test coverage despite contributing real behaviour:

- `MusicLibraryWeb.LiveHelpers.RecordActions` — 9.09 % coverage. Shared handler used by both Collection and Wishlist show pages.
- `MusicLibraryWeb.Components.Chat` — 25.87 % coverage. The streaming AI chat sheet used on Collection/Wishlist/Artist pages.

## Evidence

From `mix test --cover` in the 2026-04-16 audit:

- `LiveHelpers.RecordActions` — 9.09 %
- `Components.Chat` — 25.87 %
- `StatsLive.TopAlbums` — 20-30 %
- `StatsLive.TopArtists` — 30-39 %

Both `LiveHelpers.RecordActions` and `Components.Chat` contain branches for error paths (refresh failures, streaming errors) that are not exercised.

## Fix

- For `LiveHelpers.RecordActions`: unit-test each handler (`refresh_cover`, `populate_genres`, `generate_embeddings`, `refresh_musicbrainz_data`) both the success and error branches. These can be tested via `Phoenix.LiveViewTest` against either Collection or Wishlist Show.
- For `Components.Chat`: test the streaming state transitions (starting, receiving chunks, error, completed) and the message submission path. Streaming can be faked via `Req.Test` or behaviour stubs.

## Acceptance Criteria
<!-- AC:BEGIN -->
- `LiveHelpers.RecordActions` reaches at least 70 % line coverage
- `Components.Chat` reaches at least 60 % line coverage
- Both happy and error paths covered
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 `LiveHelpers.RecordActions` reaches at least 70 % line coverage
- [ ] #2 `Components.Chat` reaches at least 60 % line coverage
- [ ] #3 Both happy and error paths covered
<!-- AC:END -->
