---
id: ML-146
title: Honour Retry-After and rate-limit reset headers for precise snooze
status: To Do
assignee: []
created_date: '2026-04-24 11:12'
labels: []
dependencies:
  - ML-21
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Follow-up to ML-21.

Once workers classify API errors as transient vs permanent, the next refinement is using per-response retry hints instead of fixed snooze durations.

## What each API provides

| API | Header | Format |
|-----|--------|--------|
| MusicBrainz | `Retry-After` | seconds (on 503) |
| Wikipedia REST v1 / Action API | `Retry-After` | seconds (on 429 / 503 from `maxlag`) |
| Discogs | `X-Discogs-Ratelimit-Remaining` + rolling 60s window | no `Retry-After`; fallback to a fixed backoff |
| Brave Search | `X-RateLimit-Reset` | seconds until reset (comma-separated for multi-window policies) |
| OpenAI | `x-ratelimit-reset-requests`, `x-ratelimit-reset-tokens` | duration string (e.g. `120ms`, `2s`) |
| Last.fm | none | keep existing `ErrorResponse.retry_delay/1` fallback |

## Why this is a follow-up and not part of ML-21

ML-21 gets us from "no classification" to `:retry | :cancel`. That alone lets workers do the right thing with Oban's default backoff. This task layers on precision: turning `{:snooze, 60}` into `{:snooze, retry_after}` so we don't needlessly hammer rate-limited APIs or wait longer than necessary after a transient blip.

## Suggested scope

- Extract a helper that parses each API's reset/retry header into seconds
- When the classifier returns `:retry`, emit `{:snooze, seconds}` using the parsed value when available
- Clamp to a sane range (e.g. 5–300s) to guard against malformed headers
- Unit test per-API header parsing with fixture responses

## Dependencies

Blocked by ML-21 — requires the classification plumbing to exist first.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Each API module extracts a retry-delay value from its response (Retry-After, X-RateLimit-Reset, x-ratelimit-reset-*) when present
- [ ] #2 Workers emit {:snooze, seconds} with the parsed value for transient errors, falling back to a fixed default when the header is absent or malformed
- [ ] #3 Parsed durations are clamped to a safe range to prevent pathological values
- [ ] #4 Per-API header parsing is covered by unit tests using representative fixture responses
<!-- AC:END -->
