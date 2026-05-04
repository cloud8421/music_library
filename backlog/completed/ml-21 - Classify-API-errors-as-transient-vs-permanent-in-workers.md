---
id: ML-21
title: Classify API errors as transient vs permanent in workers
status: Done
assignee: []
created_date: "2026-04-20 08:50"
updated_date: "2026-04-24 11:59"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/158"
priority: medium
ordinal: 1000
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

| API                           | Error channel                        | Rate limit status                     | Body shape                                                         | Retry hint                                |
| ----------------------------- | ------------------------------------ | ------------------------------------- | ------------------------------------------------------------------ | ----------------------------------------- |
| Last.fm                       | HTTP 200 + body                      | code `29` in body                     | `{"error": N, "message": "..."}`                                   | none (already handled)                    |
| MusicBrainz                   | HTTP status                          | **503** (not 429)                     | `{"error": "string"}`                                              | `Retry-After`                             |
| Discogs                       | HTTP status                          | 429                                   | `{"message": "..."}`                                               | `X-Discogs-Ratelimit-*`, no `Retry-After` |
| Wikipedia REST v1             | HTTP status                          | 429                                   | `{"httpCode", "messageTranslations"}`                              | `Retry-After`                             |
| Wikipedia/Wikidata Action API | **HTTP 200 + body** (Last.fm-shaped) | 429 or 503                            | `{"error": {"code", "info"}}`                                      | `Retry-After` on 503                      |
| Brave Search                  | HTTP status                          | 429                                   | `{"type": "ErrorResponse", "error": {"status", "code", "detail"}}` | `X-RateLimit-Reset` (seconds)             |
| OpenAI                        | HTTP status + body `code`            | 429 for **both** rate limit and quota | `{"error": {"type", "code", "message", "param"}}`                  | `x-ratelimit-reset-*`                     |

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

- [x] #1 MusicBrainz, Discogs, Wikipedia REST v1, Brave Search, and OpenAI API modules expose a classifier that maps {status, body} to :retry or :cancel
- [x] #2 Wikipedia Action API responses (wbgetentities, prop=extracts) decode HTTP 200 bodies containing {"error": ...} into {:error, reason} instead of {:ok, body}
- [x] #3 OpenAI classifier distinguishes rate_limit_exceeded (retry) from insufficient_quota (cancel) despite both being HTTP 429
- [x] #4 MusicBrainz classifier treats 503 as the rate-limit signal (not 429) and is documented as such
- [x] #5 Workers using these APIs use the classifier to return {:snooze, n} / {:error, reason} / {:cancel, reason} instead of bubbling raw bodies
- [x] #6 Existing LastFm.API.ErrorResponse behaviour is preserved
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## Summary

Introduced structured per-API `ErrorResponse` modules for MusicBrainz, Discogs, Wikipedia, Brave Search, and OpenAI, so workers can now distinguish transient failures (rate limit, 5xx, timeout) from permanent ones (4xx, not found, auth, quota). Workers emit `{:snooze, seconds}` / `{:cancel, reason}` / `{:error, reason}` instead of bubbling raw bodies. Preserved the existing `LastFm.API.ErrorResponse` behaviour and added struct-based `retryable?/1` / `retry_delay_seconds/1` helpers so Last.fm plugs into the same handler.

## What changed

**New shared modules**

- `MusicLibrary.HttpError` — default HTTP status → kind mapping
- `MusicLibrary.Worker.ErrorHandler.to_oban_result/1` — maps any known `ErrorResponse` struct to the correct Oban tuple; passes through `{:ok, _}`, `{:cancel, _}`, and atom-reason errors unchanged

**New per-API `ErrorResponse` modules**

- `MusicBrainz.API.ErrorResponse` — maps 503 to `:rate_limit` (MusicBrainz-specific; 429 is not used upstream)
- `Discogs.API.ErrorResponse`
- `Wikipedia.API.ErrorResponse` — has a dedicated `from_action_api_body/1` for HTTP 200 Action API error envelopes (AC2 silent-bug fix)
- `BraveSearch.API.ErrorResponse`
- `OpenAI.API.ErrorResponse` — disambiguates HTTP 429 between `rate_limit_exceeded` (retry) and `insufficient_quota` (cancel) via body `code` (AC3)

**Updated API modules** — each now attaches a `parse_error/1` Req response step that halts with the appropriate struct on failure:

- `MusicBrainz.API`, `Discogs.API`, `Wikipedia.API`, `BraveSearch.API`
- `OpenAI.API` — `gpt/2`, `get_embeddings/2`, and `chat_stream/6` now return `{:error, %OpenAI.API.ErrorResponse{}}` instead of `{:error, "OpenAI API error: " <> inspect(body)}` strings

**Updated workers** to route through `ErrorHandler.to_oban_result/1`, preserving existing atom-cancel branches (`:no_english_wikipedia`, `:cover_not_available`, `:image_not_found`, `:no_discogs_data`):

- `ArtistRefreshMusicBrainzData`, `ArtistRefreshDiscogsData`, `ArtistRefreshWikipediaData`
- `FetchArtistInfo`, `FetchArtistImage`, `FetchArtistLastFmData`
- `RefreshCover`, `RecordRefreshMusicBrainzData`
- `ImportFromMusicbrainzRelease`, `ImportFromMusicbrainzReleaseGroup`
- `PopulateGenres`, `GenerateRecordEmbedding`

`RefreshScrobbles` unchanged (already had its own `ErrorResponse` routing).

## Notable fixes along the way

- Wikipedia silent bug (AC2): Action API returned `{:ok, %{"error" => ...}}` to callers when the body contained an error envelope. Now properly surfaced as `{:error, %Wikipedia.API.ErrorResponse{}}`.
- `lib/music_library_web/components/chat.ex`: Logger interpolation of the error reason (`"Chat streaming error: #{reason}"`) broke on struct errors. Switched to `inspect(reason)`.

## Tests

- New: `test/music_library/worker/error_handler_test.exs`, `test/music_brainz/api_test.exs`, `test/last_fm/api/error_response_test.exs`
- Added per-API error-classification assertions to existing `test/open_ai/api_test.exs`, `test/brave_search/api_test.exs`, `test/discogs_test.exs`, `test/wikipedia_test.exs`
- Updated callers that previously asserted on raw error bodies / string errors (`records_test.exs`, `similarity_test.exs`, worker tests)

Full verification: `mise run dev:precommit` — shellcheck, credo --strict, sobelow, gettext, format, unused deps, 871 tests pass (43 doctests). Dialyzer shows 2 pre-existing warnings unrelated to this change.

## Out of scope (ML-146)

Honouring `Retry-After` / `X-*-Reset` headers to derive precise snooze durations — each ErrorResponse module currently returns fixed per-kind defaults (30–60 s).

<!-- SECTION:FINAL_SUMMARY:END -->
