---
id: ML-71
title: page_title/2 public in two LiveViews
status: Done
assignee: []
created_date: '2026-04-20 08:55'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/104'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-12 · updated 2026-03-12 · closed 2026-03-12_

## Description

Per project conventions, `page_title/2` should be a pattern-matched private function. Two LiveViews expose it as `def` (public):

- `lib/music_library_web/live/collection_live/show.ex:477`
- `lib/music_library_web/live/wishlist_live/show.ex:421`

While `artist_live/show.ex:705` and `record_set_live/show.ex:259` correctly use `defp`. No external callers exist for the public versions.

## Expected behavior

Change `def page_title` to `defp page_title` in both files.

## Source

From technical debt audit (2026-03-12).
<!-- SECTION:DESCRIPTION:END -->
