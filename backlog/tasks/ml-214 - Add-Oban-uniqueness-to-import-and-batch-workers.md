---
id: ML-214
title: Add Oban uniqueness to import and batch workers
status: Done
assignee: []
created_date: "2026-06-10 10:39"
updated_date: "2026-06-10 12:49"
labels:
  - oban
dependencies: []
references:
  - lib/music_library/worker/import_from_musicbrainz_release.ex
  - lib/music_library/worker/backfill_scrobbled_tracks.ex
  - lib/music_library/worker/record_refresh_all_musicbrainz_data.ex
  - lib/music_library/worker/record_generate_all_embeddings.ex
  - lib/music_library/listening_stats.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: medium
ordinal: 47000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Three uniqueness gaps allow wasteful duplicate job execution (data stays safe thanks to unique indexes and on_conflict: :nothing, but API calls and retries are wasted):

1. `ImportFromMusicbrainzRelease` (lib/music_library/worker/import_from_musicbrainz_release.ex:8) has no `unique:` option — its sibling `ImportFromMusicbrainzReleaseGroup` has `unique: [period: 300, keys: [...]]`. A re-scanned barcode enqueues a duplicate; the insert hits the records unique index, returns `{:error, %Ecto.Changeset{}}`, and Oban retries 3 times, fetching MusicBrainz each attempt. The changeset error is permanent and should cancel, not retry.
2. The five `*All` batch workers (`RecordRefreshAllMusicBrainzData`, `RecordGenerateAllEmbeddings`, `ArtistRefreshAllMusicBrainzData`, `ArtistRefreshAllDiscogsData`, `ArtistRefreshAllWikipediaData`) have no `unique:` — a manual trigger while a cron run is still streaming double-enqueues every per-record job.
3. `BackfillScrobbledTracks` (self-chaining) has no `unique:` — a manual re-trigger mid-chain starts a parallel chain duplicating Last.fm API calls until history is exhausted.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 ImportFromMusicbrainzRelease has unique: [period: 300, keys: [:release_id]] and returns {:cancel, reason} when the import fails with an Ecto.Changeset error
- [x] #2 The five \*All batch workers deduplicate against incomplete jobs (unique over non-completed states) so a manual trigger during a running batch is a no-op
- [x] #3 BackfillScrobbledTracks enforces a single active chain (unique on to_uts over incomplete states) at both the worker and the ListeningStats enqueue site
- [x] #4 Worker tests assert duplicate enqueue is rejected/deduplicated for each worker and assert the changeset→cancel behaviour for the import worker
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. ImportFromMusicbrainzRelease: add `unique: [period: 300, keys: [:release_id]]` to `use Oban.Worker`; add a `{:error, %Ecto.Changeset{}} -> {:cancel, :already_imported}` clause before the ErrorHandler fallback. ✅ Done.

2. Add `unique: [period: :infinity, states: :incomplete]` to the five \*All batch workers so any retained incomplete bulk job blocks duplicates, while completed jobs do not block future runs. ✅ Done.

3. BackfillScrobbledTracks: add `unique: [period: :infinity, keys: [:to_uts], states: :incomplete]`. Both enqueue sites (ListeningStats.backfill_scrobbled_tracks/0 and self-chain) go through Worker.new + Oban.insert. ✅ Done.

4. Tests: assert duplicate enqueue conflicts, completed-job re-enqueue, and stale incomplete-job conflicts for bulk/backfill workers; assert the ListeningStats backfill enqueue site applies uniqueness; assert import worker changeset→cancel behaviour. ✅ Done.

**Deviation from original plan**: The `records_musicbrainz_id_format_index` unique index was removed in migration `20250226105533`. The `{:error, %Ecto.Changeset{}}` clause is now a safety net. The changeset→cancel test temporarily creates the index to exercise the code path. Oban testing mode returns `{:ok, %Oban.Job{conflict?: true}}` for duplicates, not `{:error, changeset}`.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Implementation complete. Key findings:

1. **Unique index removed**: The `records_musicbrainz_id_format_index` unique index was dropped in migration `20250226105533_remove_unique_index_from_records.exs`. The task description's claim about unique index violations was outdated. The `{:error, %Ecto.Changeset{}}` clause is now a safety net.

2. **Oban testing mode**: In testing mode, `Oban.insert` returns `{:ok, %Oban.Job{conflict?: true}}` for duplicates rather than `{:error, changeset}`. Tests assert `conflict?: true` and matching job IDs.

3. **Barcode scan test**: Updated to use different release fixtures (marbles + queen_greatest_hits) so uniqueness on `release_id` doesn't deduplicate the two barcode scans.

4. **Changeset→cancel test**: Uses a temporary unique index in the test (created + dropped) to trigger the error path, since the production index was removed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Added Oban uniqueness to import and batch workers to prevent wasteful duplicate job execution:

**Workers modified:**

- `ImportFromMusicbrainzRelease`: `unique: [period: 300, keys: [:release_id]]` plus a `{:cancel, :already_imported}` safety-net clause for changeset failures.
- `RecordRefreshAllMusicBrainzData`, `RecordGenerateAllEmbeddings`, `ArtistRefreshAllMusicBrainzData`, `ArtistRefreshAllDiscogsData`, and `ArtistRefreshAllWikipediaData`: `unique: [period: :infinity, states: :incomplete]` so any incomplete bulk job blocks duplicates for as long as it is retained, while completed jobs do not block future cron/manual runs.
- `BackfillScrobbledTracks`: `unique: [period: :infinity, keys: [:to_uts], states: :incomplete]`.
- `ListeningStats.backfill_scrobbled_tracks/0` and the backfill self-chain enqueue through `Oban.insert/1` so worker uniqueness is applied consistently.

**Tests added/updated:**

- Import worker tests cover duplicate enqueue conflicts and changeset-to-cancel behaviour.
- Bulk worker tests cover immediate duplicate conflicts, completed-job re-enqueue, and stale incomplete-job conflicts for all five `*All` workers.
- Backfill worker tests cover duplicate conflicts, completed-job re-enqueue, stale incomplete-job conflicts, and the `ListeningStats.backfill_scrobbled_tracks/0` enqueue site.
- Barcode scan UI test now uses distinct MusicBrainz release fixtures so release-level uniqueness does not collapse the two expected imports.

**Verification:**

- Focused worker and barcode-scan test files pass.
- `mix format --check-formatted` passes for changed Elixir files.
- `mix credo --strict` reports no issues.
<!-- SECTION:FINAL_SUMMARY:END -->
