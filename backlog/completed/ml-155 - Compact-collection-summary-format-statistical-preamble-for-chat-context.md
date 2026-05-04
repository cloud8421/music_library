---
id: ML-155
title: Compact collection summary format + statistical preamble for chat context
status: Done
assignee: []
created_date: "2026-05-01 21:43"
updated_date: "2026-05-01 21:49"
labels: []
dependencies: []
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Reduce the token count of collection_summary/0 by:

1. Compacting format_group/1 (year-only dates, remove type field, reduce max genres 3→2)
2. Adding statistical preamble (genre/formats/decade distribution) computed inline from fetched records
3. Updating tests for the new format
<!-- SECTION:DESCRIPTION:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Compacted collection_summary format_group/1: year-only dates, removed type field, reduced max genres 3→2. Added statistical preamble (genre/formats/eras distribution + artist count) computed in-memory from already-fetched records. ~27% token reduction (~26.4k → ~19.4k for 1200 records). All 886 tests pass.

<!-- SECTION:FINAL_SUMMARY:END -->
