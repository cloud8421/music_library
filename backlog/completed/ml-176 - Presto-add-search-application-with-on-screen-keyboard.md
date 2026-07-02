---
id: ML-176
title: "Presto: add search application with on-screen keyboard"
status: Done
assignee: []
created_date: "2026-05-10 13:34"
updated_date: "2026-05-11 06:47"
labels:
  - presto
milestone: m-0
dependencies:
  - ML-176.1
  - ML-176.2
priority: medium
ordinal: 3000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Add a search feature to the Presto application that lets users type a query on an on-screen QWERTY keyboard, search the collection via a new API query parameter, and browse results reusing the existing record list and detail views.

The app is unified with the existing "Records On This Day" calendar: boot shows a splash screen with two entry points — "Search Collection" and "Today's Records".

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Splash screen on boot shows 'Search Collection' and 'Today's Records' entry points
- [ ] #2 User can search the collection by typing on an on-screen QWERTY keyboard and tapping OK
- [ ] #3 Search results display as a scrollable list of records with cover art, title, artist, format, and year
- [ ] #4 Tapping a search result opens the record detail view (same as day view detail)
- [ ] #5 Back navigation is context-aware: returns to search results from search detail, to day view from day detail
- [ ] #6 Existing 'Records On This Day' calendar flow is unchanged
- [ ] #7 GET /api/v1/collection accepts optional q parameter for FTS5 full-text search
- [ ] #8 Empty query on API returns all records (backward compatible)

<!-- AC:END -->
