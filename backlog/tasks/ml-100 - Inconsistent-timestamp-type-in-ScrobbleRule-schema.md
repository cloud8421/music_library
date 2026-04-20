---
id: ML-100
title: Inconsistent timestamp type in ScrobbleRule schema
status: Done
assignee: []
created_date: '2026-04-20 08:58'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/74'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-02-17 · updated 2026-03-06 · closed 2026-03-06_

## Priority: Medium

## Description

`lib/music_library/scrobble_rules/scrobble_rule.ex:24` uses bare `timestamps()` while all other schemas explicitly use `timestamps(type: :utc_datetime)`. This means ScrobbleRule timestamps default to `:naive_datetime` instead of `:utc_datetime`.

## Expected behavior

All schemas should consistently use `timestamps(type: :utc_datetime)`.

## Source

From technical debt audit (2026-02-17), item #1.
<!-- SECTION:DESCRIPTION:END -->
