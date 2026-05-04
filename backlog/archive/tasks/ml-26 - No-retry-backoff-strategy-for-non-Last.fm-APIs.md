---
id: ML-26
title: No retry/backoff strategy for non-Last.fm APIs
status: To Do
assignee: []
created_date: "2026-04-20 08:51"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/153"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-09 · closed 2026-04-08 · not planned_

## Summary

Only the Last.fm integration has structured error responses with retry classification (`{:snooze, seconds}`). All other API integrations (MusicBrainz, Discogs, Wikipedia, Brave Search, OpenAI) use simple `max_attempts: 3` with no backoff, causing immediate retries that can trigger upstream rate limits.

## Why This Matters

- Immediate retries on transient failures can cause thundering herd effects
- Rate limit errors are treated identically to other transient errors
- No exponential backoff means the same failure is likely to repeat

## Evidence

- `lib/last_fm/api/error_response.ex` — comprehensive error classification (70 lines)
- All other API modules return raw bodies on error with no classification
- `lib/music_library/worker/refresh_scrobbles.ex` (lines 26-32) — only worker with `{:snooze, seconds}`

## Suggested Fix

1. Add structured error response modules for MusicBrainz, Discogs, and Wikipedia
2. Implement backoff strategies in their respective workers
3. Classify rate-limit responses separately from transient errors

## Acceptance Criteria

<!-- AC:BEGIN -->

- API-specific workers handle rate-limit responses with appropriate snooze durations
- Transient errors use exponential backoff rather than immediate retry
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 API-specific workers handle rate-limit responses with appropriate snooze durations
- [ ] #2 Transient errors use exponential backoff rather than immediate retry
<!-- AC:END -->
