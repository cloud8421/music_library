---
id: ML-193
title: Add secondary parser search and API coverage
status: To Do
assignee: []
created_date: "2026-05-20 17:19"
updated_date: "2026-05-20 17:20"
labels:
  - testing
  - coverage
dependencies: []
documentation:
  - docs/architecture.md
  - docs/project-conventions.md
  - .agents/skills/testing/SKILL.md
  - .agents/skills/ui-framework/SKILL.md
  - .agents/skills/external-api-integration/SKILL.md
priority: medium
ordinal: 36000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Add focused tests for low-coverage modules where direct tests would be more diagnostic than broad end-to-end coverage. Focus on universal search record-set/navigation behavior, MusicBrainz parser helpers, Last.fm session XML edge cases, HTTP/API error classification, the Wikipedia worker cancel path, and StatsComponents on-this-day rendering branches.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Universal search tests cover record-set results and counts when record sets match by name, description, contained record title, or artist name.
- [ ] #2 Universal search tests cover navigation events for collection records, wishlist records, artists, record sets, navigation links, and view-all collection/wishlist/record-set actions.
- [ ] #3 MusicBrainz parser tests cover ReleaseGroup artist credits with joinphrases, included release-group filtering, release ID extraction, parse_record_type precedence for live and compilation albums, and ReleaseSearchResult handling of missing release groups or unknown media formats.
- [ ] #4 LastFm.Session tests cover non-subscriber XML, missing subscriber, and missing name/key nodes with explicit expected struct values.
- [ ] #5 HTTP/API error tests cover MusicLibrary.HttpError default status-kind mapping and Discogs.API.ErrorResponse fallback message and retry-delay behavior.
- [ ] #6 ArtistRefreshWikipediaData worker tests cover the {:cancel, :no_english_wikipedia} branch when Wikipedia reports no English article.
- [ ] #7 StatsComponents or page-level tests cover grouped on-this-day records and anniversary labels for Today, normal years, 5-year, and 10-year milestones.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Read docs/architecture.md, docs/project-conventions.md, .agents/skills/testing/SKILL.md, and the UI/external API skill guidance before editing tests.
2. Extend universal search tests with record set fixtures and navigation assertions; prefer PhoenixTest and unwrap only where direct LiveView event interaction is needed.
3. Add direct parser tests for MusicBrainz.ReleaseGroup and MusicBrainz.ReleaseSearchResult using small explicit maps plus existing fixtures where helpful.
4. Expand LastFm.Session tests beyond doctests with explicit XML examples for non-subscriber and missing-node cases.
5. Add table-style tests for MusicLibrary.HttpError and Discogs.API.ErrorResponse that assert concrete kinds, messages, retryability, and retry delays.
6. Add the ArtistRefreshWikipediaData no-English-Wikipedia worker branch using a Wikipedia stub or context setup that produces {:error, :no_english_wikipedia}.
7. Cover StatsComponents on-this-day grouped and anniversary rendering through the page if practical, otherwise use focused component rendering consistent with local patterns.
8. Run the new/modified targeted tests and any broader affected test files.
<!-- SECTION:PLAN:END -->
