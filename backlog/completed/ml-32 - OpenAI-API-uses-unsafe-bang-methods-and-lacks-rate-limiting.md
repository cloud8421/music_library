---
id: ML-32
title: OpenAI API uses unsafe bang methods and lacks rate limiting
status: Done
assignee: []
created_date: '2026-04-20 08:52'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/147'
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-05 · updated 2026-04-05 · closed 2026-04-05_

## Summary

The OpenAI API client is the only integration that uses `Req.post!()` (bang methods) which raise on failure instead of returning error tuples. It also lacks rate limiting, breaking the pattern established by all other API integrations.

## Why This Matters

- `Req.post!()` raises on HTTP errors instead of returning `{:error, reason}` tuples, risking unhandled crashes in production
- Every other API client (MusicBrainz, Last.fm, Discogs, Wikipedia, Brave Search) attaches `Req.RateLimiter` — OpenAI does not
- `OpenAI.Config` is missing the `api_cooldown` field present in all other Config modules
- This is the only integration that breaks the three-module pattern (Facade/API/Config)

## Affected Files

- `lib/open_ai/api.ex` (lines 20, 79 — `Req.post!()` calls)
- `lib/open_ai/config.ex` (missing `api_cooldown` field)

## Suggested Fix

1. Replace `Req.post!()` with `Req.post()` and handle error tuples
2. Add `api_cooldown` to `OpenAI.Config`
3. Attach `Req.RateLimiter` in the request pipeline

## Acceptance Criteria
<!-- AC:BEGIN -->
- OpenAI API calls return `{:ok, _}` / `{:error, _}` tuples like all other integrations
- Rate limiter is attached with a configurable cooldown
- `OpenAI.Config` follows the same structure as other API Config modules
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 OpenAI API calls return `{:ok, _}` / `{:error, _}` tuples like all other integrations
- [ ] #2 Rate limiter is attached with a configurable cooldown
- [ ] #3 `OpenAI.Config` follows the same structure as other API Config modules
<!-- AC:END -->
