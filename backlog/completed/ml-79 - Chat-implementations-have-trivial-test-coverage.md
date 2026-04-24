---
id: ML-79
title: Chat implementations have trivial test coverage
status: Done
assignee: []
created_date: '2026-04-20 08:57'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/96'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-05 · updated 2026-03-05 · closed 2026-03-05_

## Priority: Medium

## Description

`ArtistChat` and `RecordChat` test files only verify `function_exported?/3`:

- `test/music_library/artist_chat_test.exs` (10 LOC) — only checks callback export
- `test/music_library/record_chat_test.exs` (10 LOC) — only checks callback export

The actual business logic in `build_instructions/2`, `build_context/3`, and instruction building is untested.

## Expected behavior

Add tests for instruction building and context assembly logic.

## Source

From technical debt audit (2026-03-05).
<!-- SECTION:DESCRIPTION:END -->
