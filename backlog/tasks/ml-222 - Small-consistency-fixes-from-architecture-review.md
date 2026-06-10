---
id: ML-222
title: Small consistency fixes from architecture review
status: To Do
assignee: []
created_date: "2026-06-10 10:41"
updated_date: "2026-06-10 10:57"
labels:
  - chore
dependencies: []
references:
  - lib/music_library/worker/refresh_scrobbles.ex
  - lib/music_library/worker/apply_scrobble_rules.ex
  - lib/music_library/artists.ex
  - lib/music_library_web/live/artist_live/show.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: low
ordinal: 55000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Four small, unrelated consistency findings from the 2026-06-10 architecture review, grouped to avoid task spam. Implement as separate single-purpose commits, each referencing this task:

1. **RefreshScrobbles bypasses ErrorHandler** (lib/music_library/worker/refresh_scrobbles.ex:26-31): re-implements retryable/snooze logic with the atom-based `LastFm.API.ErrorResponse` API instead of `MusicLibrary.Worker.ErrorHandler.to_oban_result/1` (which already supports the LastFm struct). If a new retryable error code without a defined delay were added, the manual `retry_delay |> div(1000)` path would crash on nil; the ErrorHandler path has the safe fallback.
2. **Stale moduledoc** (lib/music_library/worker/apply_scrobble_rules.ex:5): says "runs every 30 minutes"; the cron schedule is every 12 hours (config/prod.exs).
3. **Undocumented upsert contract** (lib/music_library/artists.ex:215-218): `create_artist_info/1` replaces only `musicbrainz_data` and `discogs_data` on conflict — `wikipedia_data`/`lastfm_data` are intentionally preserved and refreshed via dedicated paths. Add a comment stating this so the on_conflict list isn't "fixed" by accident.
4. **ArtistLive.Show mount doesn't set @current_section** (lib/music_library_web/live/artist_live/show.ex:510): it's assigned in apply_action instead, deviating from the documented LiveView convention (mount/3 sets @current_section). One-line assign in mount.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 RefreshScrobbles error handling delegates to ErrorHandler.to_oban_result/1; a worker test covers a retryable Last.fm error snoozing and a permanent one cancelling
- [ ] #2 ApplyScrobbleRules moduledoc states the 12-hour schedule
- [ ] #3 create_artist_info/1 documents the on_conflict field choice
- [ ] #4 ArtistLive.Show.mount/3 assigns current_section: :artists; existing artist page tests pass
- [ ] #5 Each item lands as its own commit referencing this task
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

One commit per item, each referencing ML-222:

1. refresh*scrobbles.ex: replace the manual retryable_error?/retry_delay branch (lines 26-34) with `{:error, *} = error -> ErrorHandler.to*oban_result(error)`; add/extend worker tests stubbing Last.fm via Req.Test for a retryable error (assert {:snooze, *}) and a permanent error (assert {:cancel, \_}).
2. apply_scrobble_rules.ex: correct the moduledoc to "every 12 hours" (match config/prod.exs cron).
3. artists.ex create_artist_info/1: add a comment above the on_conflict option documenting that wikipedia_data/lastfm_data are intentionally preserved and refreshed via their dedicated refresh functions.
4. artist_live/show.ex mount/3: assign current_section: :artists (keep the assignment in apply_action harmless or remove the duplicate); run artist page tests.
Finish with mix credo --strict and precommit.
<!-- SECTION:PLAN:END -->
