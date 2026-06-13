---
id: ML-222
title: Small consistency fixes from architecture review
status: Done
assignee:
  - pi
created_date: "2026-06-10 10:41"
updated_date: "2026-06-10 15:53"
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

- [x] #1 #1 RefreshScrobbles error handling delegates to ErrorHandler.to_oban_result/1; a worker test covers a retryable Last.fm error snoozing and a permanent one cancelling
- [x] #2 #2 ApplyScrobbleRules moduledoc no longer mentions a schedule to avoid doc drift
- [x] #3 #3 create_artist_info/1 documents the on_conflict field choice
- [x] #4 #4 ArtistLive.Show.mount/3 assigns current_section: :artists; existing artist page tests pass
- [x] #5 #5 Each item lands as its own commit referencing this task
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

One commit per item, each referencing ML-222:

1. refresh_scrobbles.ex: replaced the dead-code manual retryable_error?/retry_delay branch with ErrorHandler.to_oban_result/1. Also discovered that the ErrorResponse struct pattern match was dead code — LastFm.API returns atoms, not structs. The fix wraps the atom in an ErrorResponse struct before delegating. Added worker tests: success (fetches tracks), snooze on rate limit, cancel on permanent error.
2. apply_scrobble_rules.ex: removed the stale "every 30 minutes" schedule from moduledoc entirely to avoid doc drift.
3. artists.ex create_artist_info/1: added comment above on_conflict documenting that wikipedia_data/lastfm_data are intentionally preserved.
4. artist_live/show.ex mount/3: assigns current_section: :artists; removed the redundant assignment from apply_action.

Verified: mix credo --strict (clean), full test suite (1172 passed, 0 failures).

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

#1: Discovered the ErrorResponse struct branch was dead code — LastFm.API.get_recent_tracks returns {:error, atom}, not {:error, %ErrorResponse{}}. The atom-based retryable_error?/retry_delay logic could never be reached. Fixed by wrapping the atom in an ErrorResponse struct and routing through ErrorHandler, which handles both the snooze fallback (nil → 30s) and uniform Oban return values.

#2: User directed removing schedule mention entirely instead of correcting it — avoids future doc drift when cron config changes.

#3: Comment added.

#4: Assignment moved to mount/3 per LiveView convention, duplicate removed from apply_action.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Four consistency fixes from the 2026-06-10 architecture review, implemented as separate commits:

1. **RefreshScrobbles → ErrorHandler** (`15438ea0`): Replaced dead-code manual retryable_error?/retry_delay branch with `ErrorHandler.to_oban_result/1`. Discovered the ErrorResponse struct match was unreachable — `LastFm.API.get_recent_tracks` returns `{:error, atom}`, not `{:error, %ErrorResponse{}}`. The fix wraps the atom in an ErrorResponse struct so ErrorHandler can apply the snooze fallback (nil → 30s) and uniform Oban return values. Added worker tests (success, snooze on rate_limit_exceeded, cancel on invalid_session_key).

2. **ApplyScrobbleRules moduledoc** (`317ca4e9`): Removed the stale "every 30 minutes" schedule mention entirely, avoiding future doc drift when cron config changes.

3. **create_artist_info upsert contract** (`a4f16c2b`): Added comment above the `on_conflict: {:replace, [:musicbrainz_data, :discogs_data]}` option documenting that `wikipedia_data` and `lastfm_data` are intentionally preserved and refreshed via dedicated functions.

4. **ArtistLive.Show mount** (`8d290587`): Set `@current_section` in `mount/3` and removed the redundant assignment from `apply_action`. Existing artist page tests pass (11/11).

All commits pass: `mix credo --strict` (clean), full test suite (1172 passed, 0 failures).

<!-- SECTION:FINAL_SUMMARY:END -->
