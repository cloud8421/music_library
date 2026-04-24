---
id: ML-93
title: inspect(reason) exposed to users in error messages
status: Done
assignee: []
created_date: '2026-04-20 08:58'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/81'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-02-17 · updated 2026-03-05 · closed 2026-03-05_

## Priority: Medium

## Description

Across ~35 locations in `lib/music_library_web/`, error reasons are shown to users via `inspect(reason)` — e.g. `"Search failed: #{inspect(reason)}"`. This leaks internal error structures (Elixir terms) to the UI.

### Examples

- `lib/music_library_web/live/artist_live/form.ex:252,259,285,292`
- `lib/music_library_web/components/record_form.ex:541,548,574,581`
- `lib/music_library_web/live/collection_live/show.ex:85,104,124,144,163`
- `lib/music_library_web/live/wishlist_live/show.ex:71,91,110,146`

## Expected behavior

Log `inspect(reason)` for debugging but show a generic user-facing message instead.

## Source

From technical debt audit (2026-02-17), item #8.
<!-- SECTION:DESCRIPTION:END -->
