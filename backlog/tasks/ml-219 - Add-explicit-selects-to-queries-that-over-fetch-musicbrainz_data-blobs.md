---
id: ML-219
title: Add explicit selects to queries that over-fetch musicbrainz_data blobs
status: To Do
assignee: []
created_date: "2026-06-10 10:40"
updated_date: "2026-06-10 10:57"
labels:
  - perf
dependencies: []
references:
  - lib/music_library/collection/enrichment.ex
  - lib/music_library/records/similarity.ex
  - lib/music_library/records/batch.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: low
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Three query sites load full `Record` rows — including the `musicbrainz_data` JSON blob (full MusicBrainz release-group payload, potentially large per record) — where only a few fields are used:

1. `Collection.Enrichment.build_selected_release_lookup/1` (lib/music_library/collection/enrichment.ex:224-230) loads complete records for up to a page (50) of results per collection page load, to read only `id` and `musicbrainz_data`.
2. `Records.Similarity.find_similar/2` (lib/music_library/records/similarity.ex:261-278) selects full Record structs; the caller (CollectionLive.Show similar-records section) renders title/cover/artists/format only.
3. `Records.Similarity.generate_all_embeddings_async/0` (similarity.ex:358-371) and `Records.Batch.generate_embeddings/0` stream full rows to enqueue jobs that need `id` (plus title/artists for telemetry meta).

List queries elsewhere already avoid this via `essential_fields()` on SearchIndex — these three sites should follow the same discipline.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 build_selected_release_lookup selects only id and musicbrainz_data
- [ ] #2 find_similar projects only the fields its callers render (verify every consumer of the result map before narrowing)
- [ ] #3 The bulk embedding enqueue paths select only the fields they use
- [ ] #4 Tests covering Collection enrichment, similar records and bulk embedding enqueueing pass, updated where result shapes changed
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. build_selected_release_lookup (collection/enrichment.ex:224-230): add `select: %{id: r.id, musicbrainz_data: r.musicbrainz_data}` and adapt extract_selected_release to take the minimal map (or build a %Record{} shell if Record.selected_release/1 needs the struct).
2. find_similar (records/similarity.ex:261-278): grep every consumer of the returned `record` value (CollectionLive.Show template, RecordComponents card) and list the fields actually rendered; replace `record: r` with an explicit map of those fields. Update the @spec.
3. generate_all_embeddings_async (similarity.ex:358-371): add a select for id/title/artists. In Records.Batch.generate_embeddings, narrow the streamed query to the fields the per-record function uses.
4. Update tests asserting on result shapes (similarity tests, collection enrichment tests, batch tests); run them plus CollectionLive.Show tests.
5. Run dialyzer (spec changes) and precommit.
<!-- SECTION:PLAN:END -->
