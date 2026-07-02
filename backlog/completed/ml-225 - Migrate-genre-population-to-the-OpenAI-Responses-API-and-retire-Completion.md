---
id: ML-225
title: Migrate genre population to the OpenAI Responses API and retire Completion
status: Done
assignee:
  - pi
created_date: "2026-06-10 10:42"
updated_date: "2026-06-11 05:22"
labels:
  - refactor
dependencies: []
references:
  - lib/open_ai.ex
  - lib/open_ai/completion.ex
  - lib/music_library/records/enrichment.ex
  - config/config.exs
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: medium
ordinal: 58000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`Records.Enrichment.populate_genres/1` is the sole user of `OpenAI.gpt/1` and the `OpenAI.Completion` struct — a legacy path using the chat-completions endpoint pinned to gpt-4o-mini, while all chat features use the Responses API (gpt-4.1/gpt-5.1) via `OpenAI.chat_stream`. The two paths drift independently (models, error handling, endpoint deprecation risk).

Maintainer decision (2026-06-10): consolidate on the Responses API and retire `OpenAI.gpt/1` + `OpenAI.Completion`. Genre population is a non-streaming single completion, so the integration needs a non-streaming Responses API call (or to consume the stream to completion) — design this within the existing Facade/API/Config/ErrorResponse pattern. The model must be a config-driven constant (config/config.exs, per project convention) chosen deliberately: genre tagging is a cheap classification task, so a small model is appropriate; cost/behaviour may shift from gpt-4o-mini.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 populate_genres/1 uses the Responses API path; the genre output format (parsed genre list applied to the record) is unchanged
- [x] #2 OpenAI.gpt/1 and OpenAI.Completion are removed along with any now-dead specs/tests; no remaining callers (verified via grep/compile)
- [ ] #3 The genre-tagging model is read from application config, not hardcoded
- [x] #4 OpenAI.API.ErrorResponse classification still applies to the new call path (rate limit vs insufficient_quota behaviour covered by tests)
- [x] #5 Req.Test stubs and Records.Enrichment tests updated; PopulateGenres worker tests pass

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Added OpenAI.API.respond/5 — non-streaming Responses API call hitting /v1/responses, extracts text from output[0].content[0].text, same ErrorResponse.from_response/1 for error classification.
2. Added OpenAI.respond/2 facade delegating to API.respond/5 with config resolution, matching existing chat_stream/2 pattern.
3. Ported Records.Enrichment.populate_genres/1: replaced OpenAI.Completion struct + OpenAI.gpt/1 with OpenAI.respond/2. Model hardcoded as @genre_model "gpt-4.1-mini" (per user direction, no config key). Prompt intent, temperature (0.2), and parsed-genre output contract preserved.
4. Deleted OpenAI.gpt/1, OpenAI.API.gpt/2, and lib/open_ai/completion.ex. Removed all gpt/2 and Completion-related tests. Grep confirms zero remaining references. Compilation clean.
5. Updated Req.Test stubs in all 4 test files: facade test, API test, enrichment test, PopulateGenres worker test — all now stub /v1/responses with Responses API JSON shape. ErrorResponse classification tests preserved for 429 rate_limit (retryable), 429 insufficient_quota (permanent), and 500 server_error (retryable).
6. All 1174 tests pass (0 failures). Credo and Sobelow pass.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Plan adjustment (2026-06-11): User directed to hardcode gpt-4.1-mini in populate_genres/1 rather than adding a config key. AC #3 overridden — model is not config-driven for now.

All tests pass (1174 passed, 0 failures). Compilation clean. Credo and Sobelow pass. AC #3 intentionally overridden per user direction: model is hardcoded as @genre_model "gpt-4.1-mini" in Records.Enrichment.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Migrated the last remaining chat-completions API caller to the Responses API, retiring the legacy OpenAI.gpt/1 + OpenAI.Completion path.

## What changed

- **Added `OpenAI.API.respond/5`** — non-streaming call to `/v1/responses`, extracts response text from the Responses API output shape. Reuses existing `ErrorResponse.from_response/1` for error classification.
- **Added `OpenAI.respond/2` facade** — follows the same pattern as `chat_stream/2` with default model/temperature and config resolution.
- **Ported `Records.Enrichment.populate_genres/1`** — now calls `OpenAI.respond/2` with model `gpt-4.1-mini`, temperature 0.2. Prompt intent and parsed-genre output contract unchanged.
- **Deleted** `OpenAI.gpt/1`, `OpenAI.API.gpt/2`, and `OpenAI.Completion` struct (`lib/open_ai/completion.ex`).
- **Updated tests**: facade, API, enrichment, and PopulateGenres worker tests now stub `/v1/responses` with Responses API JSON shape. ErrorResponse classification tests (rate_limit retryable, insufficient_quota permanent) preserved.

## Why

The project had two OpenAI integration paths drifting independently — `chat_stream` used the Responses API (gpt-4.1/5.1) while `populate_genres` used the legacy chat-completions endpoint (gpt-4o-mini). Consolidating eliminates drift, removes the deprecated endpoint dependency, and simplifies the OpenAI module surface.

## Tests

All 1174 tests pass (0 failures). Credo and Sobelow clean. Specifically verified:

- `test/open_ai_test.exs` — facade respond/2 test
- `test/open_ai/api_test.exs` — API respond/5 (success, rate_limit, insufficient_quota, server_error)
- `test/music_library/records/enrichment_test.exs` — genre population (success, API failure)
- `test/music_library/worker/populate_genres_test.exs` — worker (success + embedding enqueue, snooze on 5xx, cancel on insufficient_quota)
- `test/music_library_web/live_helpers/record_actions_test.exs` — UI async path

## Notes

- AC #3 (config-driven model) intentionally overridden per user direction: model is hardcoded as `@genre_model "gpt-4.1-mini"` in `Records.Enrichment`.
- The `gpt-4o-mini` model is fully retired from the codebase — the only remaining hardcoded models are `gpt-4.1` (default for chat_stream/respond), `gpt-5.1` (CollectionChat), `gpt-4.1-mini` (genre), and `text-embedding-3-small` (embeddings).

<!-- SECTION:FINAL_SUMMARY:END -->
