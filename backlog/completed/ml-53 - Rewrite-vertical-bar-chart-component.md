---
id: ML-53
title: Rewrite vertical bar chart component
status: Done
assignee: []
created_date: "2026-04-20 08:54"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/122"
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-21 · updated 2026-03-21 · closed 2026-03-21_

The current vertical chart component uses SVG, which means it's not natively responsive, and it has to rely on approximated calculations which make it difficult to render nicely at every viewport.

It needs to be rewritten with standard html elements laid out in a responsive grid, so that it renders appropriately for every viewport.

<!-- SECTION:DESCRIPTION:END -->
