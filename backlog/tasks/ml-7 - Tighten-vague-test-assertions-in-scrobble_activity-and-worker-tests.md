---
id: ML-7
title: Tighten vague test assertions in scrobble_activity and worker tests
status: Done
assignee: []
created_date: '2026-04-20 08:49'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/176'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-16 · updated 2026-04-20 · closed 2026-04-20_

## Summary

Project convention: "Assert specific values, not just shape. Wildcard matches (`_`) in assertions are a signal the test is too vague." Several test files violate this.

## Evidence

### Bare `assert {:ok, _} = ...` (9 instances in one file)

`test/music_library/scrobble_activity_test.exs`: lines `43, 48, 96, 101, 154, 161, 223, 251, 272`

The context's entire job is to shape Last.fm payloads correctly, yet the tests don't inspect the returned struct's fields.

### `assert X != nil` (9 sites, 4 files)

- `test/music_library/worker/prune_assets_test.exs:14, 26, 38`
- `test/music_library/worker/fetch_artist_info_test.exs:104, 105`
- `test/music_library/barcode_scan_test.exs:23, 63, 100`
- `test/music_library/worker/fetch_artist_image_test.exs:28`

### Other `{:ok, _}` (selected)

- `test/music_library/assets_test.exs:29, 30`
- `test/music_library/records/similarity_test.exs:218, 229`
- `test/music_library/chats_test.exs:162, 203`

## Fix

For each site, replace with an assertion that pins a specific value the function is responsible for producing.

## Acceptance Criteria
<!-- AC:BEGIN -->
- `scrobble_activity_test.exs` tests assert specific struct fields on each `{:ok, _}` site
- No `assert X != nil` in worker test files (replace with value assertion)
- Suite still passes
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 `scrobble_activity_test.exs` tests assert specific struct fields on each `{:ok, _}` site
- [ ] #2 No `assert X != nil` in worker test files (replace with value assertion)
- [ ] #3 Suite still passes
<!-- AC:END -->
