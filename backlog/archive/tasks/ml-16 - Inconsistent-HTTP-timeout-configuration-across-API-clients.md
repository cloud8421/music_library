---
id: ML-16
title: Inconsistent HTTP timeout configuration across API clients
status: To Do
assignee: []
created_date: "2026-04-20 08:50"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/163"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-05 · updated 2026-04-09 · closed 2026-04-08 · not planned_

## Summary

HTTP timeout configuration varies significantly across API integrations with no documented rationale for the differences.

## Evidence

- **Last.fm**: Custom `pool_timeout: 10_000`, `receive_timeout: 2500`, `connect_timeout: 2500`
- **OpenAI GPT**: `receive_timeout: 10_000`, `connect_timeout: 2_500`
- **OpenAI Chat stream**: `receive_timeout: 60_000`, `connect_timeout: 5_000`
- **MusicBrainz, Discogs, Wikipedia, Brave Search**: Default timeouts only (no custom configuration)

## Why This Matters

- No consistency in how timeouts are configured
- Unclear whether defaults are appropriate for each API's characteristics
- Last.fm applied custom timeouts based on observed issues; other APIs may have similar unaddressed problems

## Suggested Fix

1. Audit each API's typical response times
2. Set explicit, documented timeout values for all API clients
3. Consider making timeouts configurable via each API's Config module

## Acceptance Criteria

<!-- AC:BEGIN -->

- All API clients have explicit, intentional timeout configuration
- Timeout choices are documented (e.g., in Config module comments)
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 All API clients have explicit, intentional timeout configuration
- [ ] #2 Timeout choices are documented (e.g., in Config module comments)
<!-- AC:END -->
