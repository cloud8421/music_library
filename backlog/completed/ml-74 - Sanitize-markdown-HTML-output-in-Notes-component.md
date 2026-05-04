---
id: ML-74
title: Sanitize markdown HTML output in Notes component
status: Done
assignee: []
created_date: "2026-04-20 08:56"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/101"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-07 · updated 2026-03-07 · closed 2026-03-07_

`lib/music_library_web/components/notes.ex:162` renders user-authored markdown via `Earmark.as_html!/2` + `raw()` without HTML sanitization.

Currently single-user so self-XSS only, but should sanitize for defense in depth.

<!-- SECTION:DESCRIPTION:END -->
