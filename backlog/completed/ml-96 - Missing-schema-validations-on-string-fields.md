---
id: ML-96
title: Missing schema validations on string fields
status: Done
assignee: []
created_date: '2026-04-20 08:58'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/78'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-02-17 · updated 2026-03-05 · closed 2026-03-05_

## Priority: Medium

## Description

Most schemas lack length validations on string fields. `OnlineStoreTemplate` is the exception — it validates `name` (max 100) and `url_template` (max 500). Other schemas like `Artist`, `Record`, `Note`, and `RecordSet` only validate presence.

## Expected behavior

Add appropriate length validations to string fields across all schemas.

## Source

From technical debt audit (2026-02-17), item #5.
<!-- SECTION:DESCRIPTION:END -->
