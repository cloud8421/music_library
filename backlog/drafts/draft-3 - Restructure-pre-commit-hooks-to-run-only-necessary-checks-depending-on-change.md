---
id: DRAFT-3
title: Restructure pre-commit hooks to run only necessary checks depending on change
status: Draft
assignee: []
created_date: '2026-05-15 08:41'
labels: []
dependencies: []
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently pre-commit hooks run the entire verification suite irrespectively of the change. This is inefficient and tedious. Some examples of annoyances.

1. Changes to /backlog items only need the pretty linter.
2. Changes to documentation only need the pretty linter.
3. Changes to the presto application only need to run the (upcoming) presto test suite.
4. Possibly some other patterns, need to verify the complete repo structure.
<!-- SECTION:DESCRIPTION:END -->
