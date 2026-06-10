---
id: ML-209
title: Fix missing unaccent() in Artists.search_by_name_count
status: To Do
assignee: []
created_date: "2026-06-10 10:37"
updated_date: "2026-06-10 10:55"
labels:
  - bug
dependencies: []
references:
  - lib/music_library/artists.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: high
ordinal: 42000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`Artists.search_by_name/2` (lib/music_library/artists.ex:86) filters with `lower(unaccent(artist ->> '$.name'))`, but its paired `search_by_name_count/1` (artists.ex:106) filters with `lower(...)` only. Searching "bjork" returns Björk in results but counts 0, so any pagination or result-count display built on the pair is inconsistent.

Both functions are consumed by the `Search` cross-context dispatcher (universal search). This is a regression-class divergence: ML-141 introduced accent-insensitive search, and ML-22 previously addressed search/count pair drift.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 search_by_name_count/1 applies the same lower(unaccent(...)) normalisation as search_by_name/2
- [ ] #2 A regression test creates an artist with an accented name (e.g. Björk) and asserts search_by_name/2 results and search_by_name_count/1 agree for the unaccented query
- [ ] #3 Existing artist search tests pass unchanged
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Update the fragment at lib/music_library/artists.ex:106 to `lower(unaccent(artist ->> '$.name')) LIKE ?`, mirroring search_by_name/2 at line 86.
2. Add a regression test in test/music_library/artists_test.exs: create a record whose artist is "Björk" (RecordsFixtures), then assert `Artists.search_by_name("bjork")` returns the artist AND `Artists.search_by_name_count("bjork")` equals the result count. Cover the accent-free case too ("bjork" vs "Björk" both ways).
3. Run `mix test test/music_library/artists_test.exs`, then full precommit checks.
<!-- SECTION:PLAN:END -->
