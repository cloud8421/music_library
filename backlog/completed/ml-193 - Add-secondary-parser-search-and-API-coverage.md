---
id: ML-193
title: Add secondary parser search and API coverage
status: Done
assignee: []
created_date: "2026-05-20 17:19"
updated_date: "2026-05-21 09:12"
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

- [x] #1 Universal search tests cover record-set results and counts when record sets match by name, description, contained record title, or artist name.
- [x] #2 Universal search tests cover navigation events for collection records, wishlist records, artists, record sets, navigation links, and view-all collection/wishlist/record-set actions.
- [x] #3 MusicBrainz parser tests cover ReleaseGroup artist credits with joinphrases, included release-group filtering, release ID extraction, parse_record_type precedence for live and compilation albums, and ReleaseSearchResult handling of missing release groups or unknown media formats.
- [x] #4 LastFm.Session tests cover non-subscriber XML, missing subscriber, and missing name/key nodes with explicit expected struct values.
- [x] #5 HTTP/API error tests cover MusicLibrary.HttpError default status-kind mapping and Discogs.API.ErrorResponse fallback message and retry-delay behavior.
- [x] #6 ArtistRefreshWikipediaData worker tests cover the {:cancel, :no_english_wikipedia} branch when Wikipedia reports no English article.
- [x] #7 StatsComponents or page-level tests cover grouped on-this-day records and anniversary labels for Today, normal years, 5-year, and 10-year milestones.

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Read docs/architecture.md, docs/project-conventions.md, .agents/skills/testing/SKILL.md, and the UI/external API skill guidance before editing tests.
2. Extend universal search tests with record set fixtures and navigation assertions; prefer PhoenixTest and unwrap only where direct LiveView event interaction is needed.
3. Create MusicBrainz.ReleaseGroup direct parser tests using small explicit maps plus existing fixtures where helpful.
4. Expand LastFm.Session tests beyond doctests with explicit XML examples for non-subscriber and missing-node cases.
5. Create table-style tests for MusicLibrary.HttpError and add Discogs.API.ErrorResponse fallback message and retry-delay tests.
6. Add the ArtistRefreshWikipediaData no-English-Wikipedia worker branch test using Wikipedia stub.
7. Cover StatsComponents on-this-day grouped and anniversary rendering via the page-level stats test.
8. Run tests to verify.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Added ~70 focused tests across 9 test files:

**#1 Record set search** (`test/music_library/search_test.exs`): Tests for universal_search returning record sets by name, description, contained record title, artist name; search_counts includes record_sets_count; search_record_sets basic behavior.

**#2 Navigation events** (`test/music_library_web/live/universal_search_live/index_test.exs`): Tests for navigating to collection records, wishlist records, artists, record sets, navigation links, and verifying record sets appear in search results.

**#3 MusicBrainz parsers** (`test/music_brainz/release_group_test.exs` new, `test/music_brainz/release_search_result_test.exs` extended): Tests for parse_artist_credits with joinphrases, included_release_groups filtering, release_ids extraction, parse_record_type precedence (Live/Compilation override), and ReleaseSearchResult handling of missing release groups, unknown media formats.

**#4 LastFm.Session** (`test/last_fm/session_test.exs`): Tests for non-subscriber XML (pro: false), missing subscriber/missing name/missing key nodes with explicit struct assertions.

**#5 HTTP/API errors** (`test/music_library/http_error_test.exs` new, `test/discogs_test.exs` extended): Table-style HttpError.default_kind tests for all status ranges; Discogs ErrorResponse fallback message, retryable? and retry_delay_seconds for rate_limit/server_error/timeout/default.

**#6 Wikipedia worker** (`test/music_library/worker/artist_refresh_wikipedia_data_test.exs`): Test for {:cancel, :no_english_wikipedia} branch when Wikipedia stub returns no_enwiki fixture.

**#7 StatsComponents** (`test/music_library_web/live/stats_live/index_test.exs`): Grouped on-this-day records test (same musicbrainz_id → details/summary); anniversary label tests for Today, 5 years, 10 years, and normal year labels.

<!-- SECTION:NOTES:END -->
