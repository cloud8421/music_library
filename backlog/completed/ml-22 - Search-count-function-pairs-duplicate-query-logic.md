---
id: ML-22
title: Search + count function pairs duplicate query logic
status: Done
assignee: []
created_date: '2026-04-20 08:50'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/157'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-05 · updated 2026-04-09 · closed 2026-04-09_

## Summary

Multiple contexts have paired search/count functions that duplicate the same query construction logic — building the query once for results, then rebuilding it identically for the count.

## Evidence

- `ListeningStats.list_tracks` (lines 173-186) and `search_tracks_count` (lines 237-250) repeat LIKE/JSON extraction logic
- `Artists.search_by_name/2` (lines 83-104) and `search_by_name_count/1` (lines 106-122) repeat LIKE pattern and fragment logic

## Affected Files

- `lib/music_library/listening_stats.ex`
- `lib/music_library/artists.ex`

## Suggested Fix

Extract the shared query builder into a private function that both the search and count functions use.

## Acceptance Criteria
<!-- AC:BEGIN -->
- Query logic is defined once per search domain
- No regression in search results or counts
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Query logic is defined once per search domain
- [ ] #2 No regression in search results or counts
<!-- AC:END -->
