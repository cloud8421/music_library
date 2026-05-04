---
id: ML-146
title: Honour Retry-After and rate-limit reset headers for precise snooze
status: Done
assignee:
  - Codex
created_date: "2026-04-24 11:12"
updated_date: "2026-04-27 21:02"
labels: []
dependencies:
  - ML-21
priority: low
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Follow-up to ML-21.

Once workers classify API errors as transient vs permanent, the next refinement is using per-response retry hints instead of fixed snooze durations.

## What each API provides

| API                            | Header                                                   | Format                                                          |
| ------------------------------ | -------------------------------------------------------- | --------------------------------------------------------------- |
| MusicBrainz                    | `Retry-After`                                            | seconds (on 503)                                                |
| Wikipedia REST v1 / Action API | `Retry-After`                                            | seconds (on 429 / 503 from `maxlag`)                            |
| Discogs                        | `X-Discogs-Ratelimit-Remaining` + rolling 60s window     | no `Retry-After`; fallback to a fixed backoff                   |
| Brave Search                   | `X-RateLimit-Reset`                                      | seconds until reset (comma-separated for multi-window policies) |
| OpenAI                         | `x-ratelimit-reset-requests`, `x-ratelimit-reset-tokens` | duration string (e.g. `120ms`, `2s`)                            |
| Last.fm                        | none                                                     | keep existing `ErrorResponse.retry_delay/1` fallback            |

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

- [x] #1 Each API module extracts a retry-delay value from its response (Retry-After, X-RateLimit-Reset, x-ratelimit-reset-\*) when present
- [x] #2 Workers emit {:snooze, seconds} with the parsed value for transient errors, falling back to a fixed default when the header is absent or malformed
- [x] #3 Parsed durations are clamped to a safe range to prevent pathological values
- [x] #4 Per-API header parsing is covered by unit tests using representative fixture responses
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

# Implementation Plan

- Add a shared `MusicLibrary.RetryDelay` helper that parses retry/reset headers from `Req.Response` values, clamps parsed provider hints to 5..300 seconds, uses the maximum valid value for multi-window headers, and returns nil for absent or malformed hints.
- Extend HTTP-based API `ErrorResponse` structs with an optional `retry_delay_seconds` field populated at `from_response/1` time.
- Parse provider hints for MusicBrainz and Wikipedia `retry-after`, Brave `x-ratelimit-reset`, and OpenAI `x-ratelimit-reset-requests` / `x-ratelimit-reset-tokens`; keep Discogs and Last.fm on their existing fixed fallbacks.
- Update each affected `retry_delay_seconds/1` implementation to prefer the parsed field when present and preserve existing defaults otherwise.
- Add focused unit coverage for the shared parser, per-API parsed/fallback behavior, and one `ErrorHandler` integration assertion showing parsed values flow through to `{:snooze, seconds}`.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Implemented precise retry-delay parsing through the existing ErrorResponse callback flow. Added MusicLibrary.RetryDelay with 5..300s clamping and max-window selection for multi-window headers. MusicBrainz/Wikipedia parse Retry-After, Brave parses X-RateLimit-Reset, OpenAI parses request/token reset durations. Discogs and Last.fm remain on fixed fallbacks because they do not expose a reliable retry-delay header in scope. Verification passed: focused API/error-handler tests, full mix test suite, mix format --check-formatted, and git diff --check.

Addressed review gaps after implementation: Wikipedia Action API error promotion now passes the full Req response to `from_action_api_body/2` so `Retry-After` is preserved; OpenAI retry parsing now includes `Retry-After` and compound reset durations such as `1m30s`; `Retry-After: 0` now clamps to the 5s minimum instead of falling back. Verification passed: focused retry/API tests, full `mix test`, and `mix format --check-formatted`.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## Summary

Added shared retry-delay parsing for provider retry/reset headers and wired it into the existing structured API error flow. HTTP-based ErrorResponse structs for MusicBrainz, Wikipedia, Brave Search, and OpenAI now capture an optional parsed retry delay and prefer it from `retry_delay_seconds/1`; workers automatically emit `{:snooze, parsed_seconds}` through the existing `MusicLibrary.Worker.ErrorHandler` path.

## Details

- New `MusicLibrary.RetryDelay` parses `Retry-After`, comma-separated reset-second headers, and OpenAI duration reset headers.
- Parsed provider hints are clamped to 5..300 seconds and multi-window headers use the maximum valid parsed value.
- Existing fixed fallbacks are preserved when hints are absent or malformed.
- Discogs and Last.fm remain on current fallback behavior because they do not provide a reliable retry-delay header in this scope.
- Updated architecture docs for the new shared helper.

## Tests

- `mix test test/music_library/retry_delay_test.exs test/music_brainz/api_test.exs test/wikipedia/api_test.exs test/brave_search/api_test.exs test/open_ai/api_test.exs test/music_library/worker/error_handler_test.exs`
- `mix test`
- `mix format --check-formatted`
- `git diff --check`

## Review follow-up

- Wikipedia Action API body-error responses now preserve response headers for `Retry-After` parsing.
- OpenAI retry parsing now considers `Retry-After` alongside request/token reset headers and supports compound durations like `1m30s`.
- Zero-second retry hints clamp to the 5s minimum rather than falling back to fixed defaults.
- Architecture docs now mention header-driven snooze delays in the external API integration notes.
<!-- SECTION:FINAL_SUMMARY:END -->
