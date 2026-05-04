---
id: ML-68
title: Random data in test fixtures
status: To Do
assignee: []
created_date: "2026-04-20 08:55"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/107"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-12 · updated 2026-04-09 · closed 2026-03-16 · not planned_

## Description

Test fixtures use non-deterministic random values, which can make test failures harder to reproduce:

- `test/support/fixtures/music_library/records.ex:74` — `Enum.random(@artists)`
- `test/support/fixtures/music_library/records.ex:86` — `Enum.take_random(@genres, :rand.uniform(3))`
- `test/support/fixtures/music_library/records.ex:91` — `Enum.random(@titles)`
- `test/support/fixtures/music_library/records.ex:93` — `Enum.random(Record.formats())`
- `test/support/fixtures/music_library/records.ex:95` — `Enum.random(1969..2024)`
- `test/support/fixtures/scrobbled_tracks_fixtures.ex:16` — `Enum.random(0..86_400)`

Previously tracked in #85 (closed) but the randomness remains.

## Expected behavior

Use deterministic sequences (e.g., based on `System.unique_integer`) or seeded randomness for reproducible tests.

## Source

From technical debt audit (2026-03-12). Residual from #85.

<!-- SECTION:DESCRIPTION:END -->
