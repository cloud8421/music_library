---
id: ML-112
title: Optimise scrobble rule application
status: Done
assignee: []
created_date: "2026-04-20 08:59"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/53"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2025-09-28 · updated 2025-11-10 · closed 2025-11-10_

When applying all rules, we currently apply each rule independently on the entire database. This means that it takes a significant amount of time to apply all rules.

Instead we should be able to compose a single query to apply all album rules, and a single query to apply all artist rules.

<!-- SECTION:DESCRIPTION:END -->
