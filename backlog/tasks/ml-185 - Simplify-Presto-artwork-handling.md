---
id: ML-185
title: Simplify Presto artwork handling
status: Done
assignee: []
created_date: "2026-05-15 21:19"
updated_date: "2026-05-15 21:53"
labels:
  - api
  - presto
  - artwork
dependencies: []
documentation:
  - docs/architecture.md
  - docs/project-conventions.md
  - presto/AGENTS.md
  - presto/README.md
modified_files:
  - lib/music_library_web/controllers/collection_json.ex
  - test/music_library_web/controllers/collection_controller_test.exs
  - test/prod.hurl
  - presto/main.py
  - presto/README.md
  - presto/tests/conftest.py
  - presto/tests/test_screens.py
priority: medium
ordinal: 19000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Change the collection API artwork contract so the Presto client receives ready-to-display cover assets instead of resizing them on the device.

Current state: `MusicLibraryWeb.CollectionJSON` emits flat cover URL fields (`cover_url`, `thumb_url`, `mini_cover_url`, `micro_cover_url`). `presto/main.py` lays out list covers at 80 px (`THUMB_SIZE = px(40)` with `UI_SCALE = 2`) and detail covers at 480 px (`DETAIL_COVER_SIZE = px(240)`). The existing asset transform pipeline can already serve original images or resized images by width.

Target state: each API record representation exposes four named cover variants: `original` with no width transform, `large` at 1000 px width, `medium` at 460 px width for the Presto record detail cover, and `small` at 80 px width for the Presto record list cover. The Presto app should consume those sizes directly, center the 460 px detail cover within the 480 px display, and retain only JPEG decode/draw behavior, placeholder behavior, caching, and the existing rule that network fetches do not happen during drag redraws.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Collection API record JSON exposes four named cover variants: original, large, medium, and small.
- [x] #2 The small cover is 80 px wide for the Presto record-list cover, the medium cover is 460 px wide for the Presto record-detail cover, the large cover is 1000 px wide, and original is unscaled.
- [x] #3 The Presto application consumes the API-provided small and medium cover URLs directly and no longer contains client-side cover resizing or JPEG scale-selection logic.
- [x] #4 Presto documentation and test fixtures describe the new cover contract and no longer refer to the legacy cover URL fields.
- [x] #5 Relevant Phoenix and Presto tests are updated and pass.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Update the Phoenix collection JSON contract so records expose named cover variants with widths derived from the Presto layout and the requested 1000 px large variant.
2. Update the Presto client to read the new cover names, use the 80 px and 460 px assets directly, and remove JPEG scale-selection/resizing code while preserving caching, placeholders, and drag-scroll network avoidance.
3. Update documentation, fixtures, and smoke/contract tests so the API and device assumptions stay aligned.
4. Run the focused controller tests and Presto syntax/smoke tests; note that physical Presto behavior is not verified unless the device deployment task is run on hardware.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Both implementation subtasks are now Done. `ML-185.1` updated the collection API to emit `covers.original`, `covers.large`, `covers.medium`, and `covers.small`. `ML-185.2` updated the Presto app to consume `covers.small` and `covers.medium`, use an 80 px row cover and centered 460 px detail cover, and remove JPEG resizing/scale-selection logic. Focused Phoenix controller tests and Presto syntax/smoke tests passed. Physical Presto hardware was not tested.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Completed the artwork handling simplification across the collection API and Presto client.

The API now exposes named cover variants: `original` unscaled, `large` at 1000 px, `medium` at 460 px, and `small` at 80 px. The legacy flat cover fields were removed from the collection JSON contract.

The Presto app now consumes `covers.small` for record rows and `covers.medium` for detail pages, centers the 460 px detail cover in the 480 px display, and no longer performs JPEG dimension probing or scale-selection resizing on-device. Documentation, guidance, mock fixtures, and smoke tests were updated for the new contract.

Tests run across the subtasks: `mix test test/music_library_web/controllers/collection_controller_test.exs`; Presto syntax check; `mise run test` from `presto/`. Physical Presto hardware was not tested.

<!-- SECTION:FINAL_SUMMARY:END -->
