---
id: ML-225
title: Migrate genre population to the OpenAI Responses API and retire Completion
status: To Do
assignee: []
created_date: "2026-06-10 10:42"
updated_date: "2026-06-10 10:57"
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

- [ ] #1 populate_genres/1 uses the Responses API path; the genre output format (parsed genre list applied to the record) is unchanged
- [ ] #2 OpenAI.gpt/1 and OpenAI.Completion are removed along with any now-dead specs/tests; no remaining callers (verified via grep/compile)
- [ ] #3 The genre-tagging model is read from application config, not hardcoded
- [ ] #4 OpenAI.API.ErrorResponse classification still applies to the new call path (rate limit vs insufficient_quota behaviour covered by tests)
- [ ] #5 Req.Test stubs and Records.Enrichment tests updated; PopulateGenres worker tests pass
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Read lib/open_ai.ex, lib/open_ai/api.ex and the Chats stream provider to map the existing Responses API call shape; design a non-streaming entry point (e.g. OpenAI.respond/2 returning {:ok, text} | {:error, %ErrorResponse{}}) within the Facade/API/Config pattern.
2. Add a config key (e.g. :music_library, :openai_genre_model) in config/config.exs; pick a small model deliberately and document the choice.
3. Port Records.Enrichment.populate_genres/1 to the new entry point, preserving the prompt intent and the parsed-genre output contract.
4. Delete OpenAI.gpt/1, OpenAI.Completion and their tests; grep for remaining references (Completion, "gpt-4o-mini") and compile to confirm.
5. Update Req.Test stubs in config/test.exs / test support for the /v1/responses endpoint; add ErrorResponse classification tests for the new path (429 rate_limit → snooze-able, insufficient_quota → permanent) mirroring the existing OpenAI error tests.
6. Run enrichment, OpenAI and PopulateGenres worker tests; verify one real genre population in dev if an API key is available; precommit.
<!-- SECTION:PLAN:END -->
