---
id: ML-150
title: Extract Records sub-contexts to reduce module size
status: To Do
assignee: []
created_date: '2026-04-30 10:47'
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
- [ ] #1 `Records.Search`, `Records.Import`, and `Records.Enrichment` modules exist with focused responsibilities
- [ ] #2 Public `Records` module re-exports all previously-public functions through delegation
- [ ] #3 All callers (LiveViews, workers, controllers, tests) continue to work without changes to their import/alias lines
- [ ] #4 Full test suite passes with no regressions
- [ ] #5 `@moduledoc` for each new module explains its responsibility
<!-- AC:END -->
