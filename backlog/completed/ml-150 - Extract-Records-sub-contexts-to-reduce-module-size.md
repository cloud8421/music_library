---
id: ML-150
title: Extract Records sub-contexts to reduce module size
status: Done
assignee: []
created_date: "2026-04-30 10:47"
updated_date: "2026-04-30 16:08"
labels:
  - refactor
  - records
dependencies: []
references:
  - lib/music_library/records.ex
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

The `Records` context module (450+ lines in `lib/music_library/records.ex`) handles CRUD, FTS5 search, MusicBrainz import, cover management, genre population, color extraction, PubSub notifications, and similarity embedding dispatch — too many responsibilities for a single module.

Extract focused sub-contexts:

- `Records.Search` — FTS5 search, `SearchParser` integration, search result formatting
- `Records.Import` — MusicBrainz release/group import, barcode scan integration
- `Records.Enrichment` — genre population, color extraction, cover management, embedding dispatch

Keep the public `Records` module as a facade that re-exports key functions for backward compatibility with all existing callers (LiveViews, workers, controllers).

The `SearchIndex` schema, `Record` schema, `Similarity` module, `TracklistPdf`, and `Batch` sub-modules stay as-is. Only `records.ex` itself is being split.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 `Records.Search`, `Records.Import`, and `Records.Enrichment` modules exist with focused responsibilities
- [x] #2 Public `Records` module re-exports all previously-public functions through delegation
- [x] #3 All callers (LiveViews, workers, controllers, tests) continue to work without changes to their import/alias lines
- [x] #4 Full test suite passes with no regressions
- [x] #5 `@moduledoc` for each new module explains its responsibility

<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Implementation Summary

### New modules created

**`Records.Search`** (`lib/music_library/records/search.ex`):

- `essential_fields/0`, `search_records/3`, `search_records_count/2`, `list_genres/0`
- Private: `build_search/3`, `fts_escape/1`, `fts_query_escape/1`
- Imports `order_alphabetically` macro from `Records` (one-direction dependency, no cycle)

**`Records.Import`** (`lib/music_library/records/import.ex`):

- `get_release_status/2`, `get_artist_records/1`
- `import_from_musicbrainz_release/2`, `import_from_musicbrainz_release_group/2`
- Private: `get_cover_art_or_default/1`, `build_record_attrs/2`
- Calls `Records.create_record/1` and `Records.Search.essential_fields/0`

**`Records.Enrichment`** (`lib/music_library/records/enrichment.ex`):

- `populate_genres/1`, `populate_genres_async/1`
- `refresh_cover/1`, `refresh_cover_async/1`
- `extract_colors/1`, `resize_cover/1`
- `refresh_musicbrainz_data/1`, `refresh_musicbrainz_data_async/1`
- `best_effort_extract_colors/1` (public, called from `Records.create_record/1`)
- Private: `maybe_extract_colors/1`, `enqueue_worker/3`, `record_meta/1`
- Calls `Records.update_record/2`

### Facade (`lib/music_library/records.ex`)

- 15 `defdelegate` calls covering all moved functions (compile-time safety)
- `order_alphabetically` macro stays in `Records` for backward compatibility
- CRUD (`get_record`, `create_record`, `update_record`, `delete_record`, `change_record`) and PubSub (`subscribe`, `notify_update`) stay directly in `Records`

### Dependency graph (one direction only):

```
Records.Search → imports macro from Records
Records.Import → calls Records, Records.Search
Records.Enrichment → calls Records
Records → delegates to Search, Import, Enrichment (compile-time: defdelegate only, no runtime cycle)
```

### Tests

- `test/music_library/records_test.exs` — CRUD tests (6 tests)
- `test/music_library/records/search_test.exs` — search tests (13 tests)
- `test/music_library/records/import_test.exs` — import tests (3 tests)
- `test/music_library/records/enrichment_test.exs` — enrichment tests (3 tests)

<!-- SECTION:NOTES:END -->
