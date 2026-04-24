---
id: ML-21
title: Classify API errors as transient vs permanent in workers
status: To Do
assignee: []
created_date: '2026-04-20 08:50'
updated_date: '2026-04-24 11:12'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/158'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-05 · updated 2026-04-12 · re-scoped 2026-04-24 after per-API research_

## Summary

Workers that call MusicBrainz, Discogs, Wikipedia/Wikidata, Brave Search, and OpenAI bubble raw response bodies on error. They cannot distinguish "rate limited, snooze" from "bad request, cancel" from "server blip, retry", so Oban uses the generic `max_attempts: 3` backoff for every failure mode.

## What the original framing got wrong

The original issue pointed at `LastFm.API.ErrorResponse` as the pattern to copy across all integrations. After researching each API, that comparison doesn't hold:

- **Last.fm is the odd one out**, not the reference. It returns HTTP 200 with `{"error": N, "message": "..."}` in the body, and its 14-value error taxonomy (`invalid_session_key`, `suspended_api_key`, `service_offline`, …) is a protocol unique to Last.fm. No other API we use has that shape.
- **The REST APIs encode errors in HTTP status codes.** The only "classification" to recover is `status → transient | permanent`, plus two body-peek exceptions (see below). Copying `ErrorResponse` verbatim would produce four near-identical modules whose only job is to translate status codes.

## What each API actually returns

| API | Error channel | Rate limit status | Body shape | Retry hint |
|-----|---------------|-------------------|------------|------------|
| Last.fm | HTTP 200 + body | code `29` in body | `{"error": N, "message": "..."}` | none (already handled) |
| MusicBrainz | HTTP status | **503** (not 429) | `{"error": "string"}` | `Retry-After` |
| Discogs | HTTP status | 429 | `{"message": "..."}` | `X-Discogs-Ratelimit-*`, no `Retry-After` |
| Wikipedia REST v1 | HTTP status | 429 | `{"httpCode", "messageTranslations"}` | `Retry-After` |
| Wikipedia/Wikidata Action API | **HTTP 200 + body** (Last.fm-shaped) | 429 or 503 | `{"error": {"code", "info"}}` | `Retry-After` on 503 |
| Brave Search | HTTP status | 429 | `{"type": "ErrorResponse", "error": {"status", "code", "detail"}}` | `X-RateLimit-Reset` (seconds) |
| OpenAI | HTTP status + body `code` | 429 for **both** rate limit and quota | `{"error": {"type", "code", "message", "param"}}` | `x-ratelimit-reset-*` |

## Real quirks to encode (not 14 error atoms)

1. **MusicBrainz uses 503, not 429, for rate limits.** A generic "5xx = transient" rule already handles it; worth a comment so it isn't "fixed" by a future reader.
2. **OpenAI 429 is ambiguous.** `code: "rate_limit_exceeded"` → retry. `code: "insufficient_quota"` → cancel (billing failure, not a retryable rate limit). Must inspect the body.
3. **MediaWiki Action API returns errors inside HTTP 200 bodies.** Our current `Wikipedia.API.get_wikipedia_title/2` and `get_article_extract/2` would return `{:ok, body}` with an error payload — a silent bug. Needs a Last.fm-style `parse_error` step that converts `{"error": %{"code", "info"}}` in the body into `{:error, ...}`.

## Suggested fix

Per-API `classify/1` helpers (or a small shared module) that return `:retry | :cancel` given `{status, body}`. Workers then choose between `{:error, reason}` / `{:snooze, n}` / `{:cancel, reason}` based on that classifier.

Out of scope (tracked separately): honouring `Retry-After` / `X-*-Reset` headers to compute precise snooze durations rather than using fixed defaults.

## Evidence

- `lib/last_fm/api/error_response.ex` — existing Last.fm model, keep as-is
- `lib/music_brainz/api.ex:512-524` — `get_request/1` returns raw body on non-200
- `lib/discogs/api.ex:47-59` — same
- `lib/wikipedia/api.ex:86-97` — same, **plus** silently returns `{:ok, body}` when body is an Action API error payload
- `lib/brave_search/api.ex:67-78` — same
- `lib/open_ai/api.ex:30-31, 89-90` — same, never inspects `error.code` so treats `rate_limit_exceeded` and `insufficient_quota` identically
- `lib/music_library/worker/refresh_scrobbles.ex:26-32` — example of snooze-vs-cancel logic driven by classified errors
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Each API integration has structured error classification
- [ ] #2 Workers can distinguish transient from permanent failures
<!-- AC:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 MusicBrainz, Discogs, Wikipedia REST v1, Brave Search, and OpenAI API modules expose a classifier that maps {status, body} to :retry or :cancel
- [ ] #2 Wikipedia Action API responses (wbgetentities, prop=extracts) decode HTTP 200 bodies containing {"error": ...} into {:error, reason} instead of {:ok, body}
- [ ] #3 OpenAI classifier distinguishes rate_limit_exceeded (retry) from insufficient_quota (cancel) despite both being HTTP 429
- [ ] #4 MusicBrainz classifier treats 503 as the rate-limit signal (not 429) and is documented as such
- [ ] #5 Workers using these APIs use the classifier to return {:snooze, n} / {:error, reason} / {:cancel, reason} instead of bubbling raw bodies
- [ ] #6 Existing LastFm.API.ErrorResponse behaviour is preserved
<!-- AC:END -->
