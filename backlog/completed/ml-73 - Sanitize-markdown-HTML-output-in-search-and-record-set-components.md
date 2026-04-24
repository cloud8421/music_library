---
id: ML-73
title: Sanitize markdown HTML output in search and record set components
status: Done
assignee: []
created_date: '2026-04-20 08:56'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/102'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-07 · updated 2026-03-07 · closed 2026-03-07_

The following locations render markdown descriptions via `Markdown.to_html()` + `raw()` without HTML sanitization:

- `lib/music_library_web/components/search_components.ex:353`
- `lib/music_library_web/live/record_set_live/index.ex:472`
- `lib/music_library_web/live/record_set_live/show.ex:308`

Same pattern as the Notes component. Should sanitize for defense in depth.
<!-- SECTION:DESCRIPTION:END -->
