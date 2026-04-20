---
id: ML-21
title: Asymmetric error handling across API integrations
status: To Do
assignee: []
created_date: '2026-04-20 08:50'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/158'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-05 · updated 2026-04-12_

## Summary

Only the Last.fm integration has a structured `ErrorResponse` module that classifies errors and enables intelligent retry decisions. All other API integrations (MusicBrainz, Discogs, Wikipedia, Brave Search) return raw response bodies on error with no classification.

## Why This Matters

- Last.fm errors are classified into 7+ types with retry/snooze logic
- Other APIs treat all errors identically — no distinction between rate limits, auth failures, or transient issues
- Workers cannot make informed retry decisions for non-Last.fm APIs

## Evidence

- `lib/last_fm/api/error_response.ex` — 70 lines of comprehensive error handling
- Other API modules: no equivalent error response module

## Suggested Fix

Add error response modules for MusicBrainz, Discogs, and Wikipedia following the Last.fm pattern. At minimum, classify:
- Rate limit responses (HTTP 429)
- Server errors (5xx, transient)
- Client errors (4xx, permanent)

## Acceptance Criteria
<!-- AC:BEGIN -->
- Each API integration has structured error classification
- Workers can distinguish transient from permanent failures
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Each API integration has structured error classification
- [ ] #2 Workers can distinguish transient from permanent failures
<!-- AC:END -->
