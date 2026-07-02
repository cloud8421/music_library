---
id: ML-227
title: Fix current Dialyzer failures
status: Done
assignee:
  - assistant
created_date: "2026-06-10 16:19"
updated_date: "2026-06-10 16:28"
labels: []
dependencies: []
modified_files:
  - lib/music_brainz/release_search_result.ex
  - lib/music_library/collection/enrichment.ex
  - lib/music_library/errors.ex
priority: medium
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Run `mix dialyzer`, investigate the reported type/spec issues, and update the relevant code or specs so Dialyzer completes successfully for the current codebase.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 `mix dialyzer` completes without reported failures.
- [x] #2 Any code or type/spec changes preserve existing behavior and follow project conventions.
- [x] #3 Relevant tests are run for the changed areas, or the reason for not running them is documented in the final summary.

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

Approved plan:

1. Read project conventions before making changes.
2. Run `mix dialyzer` to capture the current warnings/failures.
3. Investigate the reported modules and decide whether each issue should be fixed with code changes or corrected specs/types.
4. Apply the smallest behavior-preserving changes needed.
5. Re-run `mix dialyzer`; run focused tests for changed areas if applicable.
6. Update the task with validation results, acceptance criteria status, and final summary.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Ran `mix dialyzer` and found two failures: `ReleaseSearchResult.format/1` was called with a selected `MusicBrainz.Release.t()`/nil path despite a `ReleaseSearchResult.t()`-only spec, and `Errors.get_error/1` advertised an `ErrorTracker.Error.t()` return whose dependency type omits API-rendered fields. Fixed by broadening the release formatter type, pattern matching selected release nil explicitly, and adding a local detailed error return type with map enrichment for occurrences/count metadata.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Summary:

- Updated `MusicBrainz.ReleaseSearchResult.format/1` to document/support both release search results and selected `MusicBrainz.Release` structs.
- Reworked selected-release enrichment to pattern match nil explicitly before formatting release data.
- Added a local `Errors.error_detail/0` type for the detailed API payload returned by `Errors.get_error/1`, and build the enriched error via `Map.put/3` so Dialyzer sees the additional occurrence metadata.

Validation:

- `mix dialyzer` passes with 0 errors.
- `mix format --check-formatted` passes.
- Focused tests pass: `mix test test/music_library/collection/enrichment_test.exs test/music_brainz/release_search_result_test.exs test/music_library/errors_test.exs test/music_library_web/controllers/error_controller_test.exs` (85 tests, 4 doctests).

<!-- SECTION:FINAL_SUMMARY:END -->
