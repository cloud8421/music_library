---
id: ML-214
title: Add Oban uniqueness to import and batch workers
status: To Do
assignee: []
created_date: "2026-06-10 10:39"
updated_date: "2026-06-10 10:56"
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

- [ ] #1 ImportFromMusicbrainzRelease has unique: [period: 300, keys: [:release_id]] and returns {:cancel, reason} when the import fails with an Ecto.Changeset error
- [ ] #2 The five \*All batch workers deduplicate against incomplete jobs (unique over non-completed states) so a manual trigger during a running batch is a no-op
- [ ] #3 BackfillScrobbledTracks enforces a single active chain (unique on to_uts over incomplete states) at both the worker and the ListeningStats enqueue site
- [ ] #4 Worker tests assert duplicate enqueue is rejected/deduplicated for each worker and assert the changeset→cancel behaviour for the import worker
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. ImportFromMusicbrainzRelease: add `unique: [period: 300, keys: [:release_id]]` to `use Oban.Worker`; add a `{:error, %Ecto.Changeset{}} -> {:cancel, :already_imported}` clause before the ErrorHandler fallback.
2. Add `unique: [period: 3600, states: Oban.Job.states() -- [:completed, :cancelled, :discarded]]` (incomplete states) to the five \*All batch workers.
3. BackfillScrobbledTracks: add `unique: [period: :infinity, keys: [:to_uts], states: <incomplete>]`; confirm both enqueue sites (ListeningStats.backfill_scrobbled_tracks/0 and the self-chain insert) go through Worker.new so the option applies.
4. Tests (Oban manual testing mode): for each worker, insert the same job twice and assert the second is a uniqueness conflict (Oban.Testing / changeset :unique error); for the import worker, stub MusicBrainz via Req.Test, pre-create the record, run perform, assert {:cancel, :already_imported}.
5. Run worker tests, then precommit.
<!-- SECTION:PLAN:END -->
