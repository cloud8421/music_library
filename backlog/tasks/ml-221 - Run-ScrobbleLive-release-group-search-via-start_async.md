---
id: ML-221
title: Run ScrobbleLive release-group search via start_async
status: To Do
assignee: []
created_date: "2026-06-10 10:41"
updated_date: "2026-06-10 10:57"
labels:
  - liveview
  - fix
dependencies: []
references:
  - lib/music_library_web/live/scrobble_live/index.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: medium
ordinal: 54000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`ScrobbleLive.Index` performs the MusicBrainz release-group search inside `handle_info` (lib/music_library_web/live/scrobble_live/index.ex:145-160), dispatched via `send(self(), {:perform_search, query})`. The send/handle_info indirection lets the loading state render first, but the HTTP call still runs in the LiveView process: MusicBrainz requests sit behind a 1000 ms rate-limit cooldown plus network latency, and every subsequent event on the page queues behind the call.

`start_async`/`handle_async` is the established pattern in this codebase for exactly this (e.g. ArtistLive.Show, StatsLive.Index).

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 The MusicBrainz search runs via start_async; the send(self(), ...)/handle_info pair is removed
- [ ] #2 handle*async covers all three cases ({:ok, {:ok, *}}, {:ok, {:error, _}}, {:exit, _}); the error path keeps the existing user-facing failure message
- [ ] #3 Loading state behaviour is preserved (spinner while searching, cleared on result/error)
- [ ] #4 A rapid second search while one is in flight does not produce stale results overwriting newer ones (cancel or ignore superseded results)
- [ ] #5 ScrobbleLive tests updated (Req.Test stub) covering success and failure paths
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. In ScrobbleLive.Index, replace `send(self(), {:perform_search, query})` with `start_async(:search, fn -> MusicBrainz.search_release_group(query, limit: 20) end)`; keep `loading: true` assign at dispatch.
2. Supersede stale searches: either `cancel_async(socket, :search)` before starting a new one, or store the current query and ignore handle_async results whose query doesn't match.
3. Implement handle_async(:search, ...) with the three cases; error case keeps the existing gettext flash message; remove the handle_info clause.
4. Update test/music_library_web/live/scrobble_live/index_test.exs: Req.Test stubs for success and failure; render_async() before asserting results; cover the failure flash.
5. Run scrobble_live tests, then precommit.
<!-- SECTION:PLAN:END -->
