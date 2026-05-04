---
id: ML-97
title: Duplicate fixture definitions in tests (partially solved)
status: Done
assignee: []
created_date: "2026-04-20 08:58"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/77"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-02-17 · updated 2026-03-06 · closed 2026-03-06_

## Priority: Medium

## Description

`scrobble_rule_fixture/1` was duplicated in `test/support/fixtures/scrobble_rules_fixtures.ex` and locally in `test/music_library/scrobble_rules_test.exs`. The local copy has been removed; the test now imports the shared fixture module.

The `scrobbled_track_fixture` naming inconsistency remains — it is defined locally in `test/music_library/scrobble_rules_test.exs:29` and not shared.

## Expected behavior

Move `scrobbled_track_fixture` to a shared fixture module for consistency.

## Source

From technical debt audit (2026-02-17), item #4.

<!-- SECTION:DESCRIPTION:END -->
