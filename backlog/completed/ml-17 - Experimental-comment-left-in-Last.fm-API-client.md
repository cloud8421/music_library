---
id: ML-17
title: Experimental comment left in Last.fm API client
status: Done
assignee: []
created_date: "2026-04-20 08:50"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/162"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-08 · closed 2026-04-08_

## Summary

`lib/last_fm/api.ex` lines 160-162 contains a comment marked as experimental regarding timeout tuning that was intended to be temporary but remains in production.

## Affected Files

- `lib/last_fm/api.ex` (lines 160-162)

## Suggested Fix

Either:

1. Validate the timeout values work well and remove the "Experimental" comment
2. Or revert to standard timeouts if the experiment didn't prove useful

## Acceptance Criteria

<!-- AC:BEGIN -->

- No experimental/temporary comments remain in production code
- Timeout configuration is intentional and documented

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 No experimental/temporary comments remain in production code
- [ ] #2 Timeout configuration is intentional and documented

<!-- AC:END -->
