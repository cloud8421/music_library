---
id: ML-211
title: Stop returning notify_update result from enrichment workers
status: To Do
assignee: []
created_date: "2026-06-10 10:38"
updated_date: "2026-06-13 16:42"
labels:
  - oban
  - fix
dependencies: []
references:
  - lib/music_library/worker/refresh_cover.ex
  - lib/music_library/worker/record_refresh_music_brainz_data.ex
  - lib/music_library/worker/populate_genres.ex
  - lib/music_library/records.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: medium
ordinal: 44000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Three Oban workers return the result of `Records.notify_update/1` (spec: `:ok | {:error, term()}`) directly as their job result:

- lib/music_library/worker/refresh_cover.ex:14
- lib/music_library/worker/record_refresh_music_brainz_data.ex:13
- lib/music_library/worker/populate_genres.ex (final expression of the success path)

`notify_update/1` is a best-effort PubSub broadcast. If it fails after the record has been successfully saved, the worker returns `{:error, term()}` and Oban retries the entire job — including the external API call (cover fetch, MusicBrainz refresh) or genre population — even though the data is already persisted. The DB is the source of truth; a missed broadcast only means a LiveView misses one live update.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 RefreshCover, RecordRefreshMusicBrainzData and PopulateGenres call Records.notify_update/1 and then return :ok explicitly on the success path
- [ ] #2 Worker tests assert the jobs return :ok when the underlying operation succeeds
- [ ] #3 Error paths (operation itself fails) are unchanged and still translate through ErrorHandler/cancel as before
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. In refresh_cover.ex and record_refresh_music_brainz_data.ex, change the success branch to:
   `{:ok, updated_record} -> Records.notify_update(updated_record); :ok` (two statements, explicit :ok).
2. In populate_genres.ex, make the `with` success body call notify_update then return :ok.
3. Update worker tests (test/music_library/worker/) to assert perform returns :ok on success, with external APIs stubbed via Req.Test. Add tests if a worker lacks a success-path assertion.
4. Run the three worker test files, then precommit.
<!-- SECTION:PLAN:END -->

## Comments

<!-- COMMENTS:BEGIN -->

author: pi
created: 2026-06-13 16:42

---

Archiving as not worth addressing after auditing `Phoenix.PubSub.broadcast/3` failure modes. In this app, PubSub uses the default `Phoenix.PubSub.PG2` adapter; `broadcast/3` is typed as `:ok | {:error, term()}`, but the default adapter's only explicit returned error is `{:error, :no_such_group}`. No subscribers and missed LiveView updates are not returned failures. Other infrastructure problems would generally raise/exit rather than return `{:error, _}`.

## The retry-on-broadcast-error concern is therefore technically valid but very low value to fix. If revisited later, note that `GenerateRecordEmbedding` has the same success-path `Records.notify_update/1` return shape as the three workers listed in this task.

<!-- COMMENTS:END -->
