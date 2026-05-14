---
id: doc-22
title: "Evaluation: Replacing OpenAI with Mistral"
type: guide
created_date: "2026-05-14 10:32"
updated_date: "2026-05-14 10:35"
tags:
  - openai
  - mistral
  - evaluation
  - migration
  - api-integration
---

# Evaluation: Replacing OpenAI with Mistral

## Summary

**Overall complexity: MEDIUM-HIGH (unchanged, but web search picture clarified)**

The discovery that Mistral offers web search via their **Studio Agents API** (a separate product
from Chat Completions / La Plateforme) changes the web search calculus. It does NOT eliminate the
gap — it shifts it to an architectural decision between two harder paths.

---

## OpenAI Integration Scope

5 call sites across 3 core capabilities:

| Capability                         | Module                 | Function               | OpenAI API endpoint    |
| ---------------------------------- | ---------------------- | ---------------------- | ---------------------- |
| Genre population (structured JSON) | `Records.Enrichment`   | `populate_genres/1`    | `/v1/chat/completions` |
| Record similarity (embeddings)     | `Records.Similarity`   | `generate_embedding/1` | `/v1/embeddings`       |
| Chat streaming (SSE + web search)  | `Chats.RecordChat`     | `stream_response/3`    | `/v1/responses`        |
| Chat streaming (SSE + web search)  | `Chats.ArtistChat`     | `stream_response/3`    | `/v1/responses`        |
| Chat streaming (SSE + web search)  | `Chats.CollectionChat` | `stream_response/3`    | `/v1/responses`        |

**Supporting modules (7 files):** `OpenAI` facade, `OpenAI.API`, `OpenAI.Config`,
`OpenAI.Completion`, `OpenAI.API.ErrorResponse`, `Worker.ErrorHandler`, `RetryDelay`.

**Tests:** 344 lines in dedicated OpenAI tests, plus references in 8 other test files.

**Config:** 3 files (`config.exs`, `runtime.exs`, `test.exs`).

---

## Complexity by Capability

### 1. Chat Streaming — HIGH 🔴

The hardest part. Current code uses OpenAI's **Responses API** (`/v1/responses`), not
Chat Completions. Mistral has **two separate APIs**, each with different trade-offs:

#### Option A: Mistral Chat Completions API (La Plateforme)

Use `/v1/chat/completions` with `stream: true`. SSE format is different from OpenAI's
Responses API — emits `choices[0].delta.content` instead of `response.output_text.delta`.
The `decode_responses_event/2` function needs a full rewrite.

**BUT: No web search support.** Mistral's Chat Completions API does NOT have a web search
tool. To keep web search, you'd need to pre-fetch via BraveSearch and inject results as
context — a material feature change.

#### Option B: Mistral Studio Agents API

Use the Studio API (`client.beta.agents.create` + `client.beta.conversations.start`).
This is a **completely different API surface** from La Plateforme:

- Requires agent creation before starting conversations
- Uses `tools: [{"type": "web_search"}]` or `"web_search_premium"`
- Different SSE event format (`tool.execution` + `message.output` interleaved chunks)
- Different base URL, different auth, possibly different rate limiting
- Includes citations (references with URLs/titles) — a nice upgrade
- Streaming plumbing (`into: :self`) is reusable, but the event decoder is entirely different

This is a materially larger rewrite than Option A, but preserves web search natively.

#### SSE Event Format Comparison

| Event type     | OpenAI Responses API         | Mistral Chat Completions   | Mistral Studio Agents                  |
| -------------- | ---------------------------- | -------------------------- | -------------------------------------- |
| Text delta     | `response.output_text.delta` | `choices[0].delta.content` | Chunks within `message.output` entries |
| Error          | `error` / `response.failed`  | Standard HTTP error        | Tool execution errors                  |
| Tool execution | N/A (inline in response)     | N/A                        | `tool.execution` entries               |
| Citations      | N/A                          | N/A                        | `tool_reference` chunks with URLs      |

#### Model Differences

`CollectionChat` uses `gpt-5.1` (very large context). Mistral equivalent for large context
would be `mistral-large-latest`. For the Studio Agents API, the docs show `mistral-medium-latest`
used with web search.

### 2. Embeddings — MEDIUM 🟡

Both use `/v1/embeddings` with near-identical response shapes. Mistral uses `mistral-embed`
vs OpenAI's `text-embedding-3-small`.

**Key concern: Dimension mismatch.** OpenAI's `text-embedding-3-small` produces 1536-dimensional
vectors. Mistral's `mistral-embed` produces 1024-dimensional vectors. The `record_embeddings`
table stores these via `sqlite-vec`. This means:

- All existing embeddings must be regenerated (mass re-embed)
- `vec_f32()` and `vec_distance_cosine` work with any dimension — no schema change needed
- Just trigger `RecordGenerateAllEmbeddings` after migration

### 3. Genre Population — LOW 🟢

Both use Chat Completions with `response_format: %{type: "json_object"}`. The `OpenAI.Completion`
struct maps cleanly. Response shape (`choices[0].message.content`) is identical. Nearly a
drop-in replacement — just change model name and base URL.

### 4. Error Handling — MEDIUM 🟡

If using Studio Agents API, error handling becomes more complex due to the multi-step
nature (agent creation can fail separately from conversation streaming). Error body shapes
differ between La Plateforme and Studio APIs.

### 5. Configuration & Tests — MEDIUM 🟡

If using both La Plateforme (for embeddings + genres) AND Studio API (for chat), you're
now managing two Mistral API keys, two base URLs, and two sets of rate limits. Tests need
stubs for both API surfaces.

---

## Mistral API Surface Map

| Need                    | OpenAI solution           | Mistral La Plateforme           | Mistral Studio Agents                  |
| ----------------------- | ------------------------- | ------------------------------- | -------------------------------------- |
| Chat completions (JSON) | `/v1/chat/completions`    | ✅ `/v1/chat/completions`       | ❌ Different API                       |
| Chat streaming          | `/v1/responses` (SSE)     | ✅ `/v1/chat/completions` (SSE) | ✅ Conversations API (SSE)             |
| Web search              | `web_search_preview` tool | ❌ Not available                | ✅ `web_search` / `web_search_premium` |
| Embeddings              | `/v1/embeddings`          | ✅ `/v1/embeddings`             | ❌ Not available                       |
| Citations in response   | ❌ Not built-in           | ❌ Not built-in                 | ✅ `tool_reference` chunks             |

---

## Revised Decision Matrix

| Path                                                                 | Web search                              | Effort     | Risk   | Note                                                            |
| -------------------------------------------------------------------- | --------------------------------------- | ---------- | ------ | --------------------------------------------------------------- |
| **A: La Plateforme only** (Chat + Embeddings)                        | ❌ Lost or manual BraveSearch injection | ~16 hours  | Medium | Simpler code, but chat loses native web search                  |
| **B: Hybrid** (La Plateforme for embeddings/genres, Studio for chat) | ✅ Native                               | ~24+ hours | High   | Two API keys, two API surfaces, complex error handling          |
| **C: Studio only** (all via Agents API)                              | ✅ Native                               | ~28+ hours | High   | Embeddings still need La Plateforme; Studio can't do embeddings |

**Recommended path**: **Option A** with BraveSearch injection for web search. This keeps the
architecture simple (one API surface), preserves web search functionality by pre-fetching
search results via the already-integrated BraveSearch API, and avoids the complexity of
managing two Mistral API products.

---

## Files Affected

### New files to create

- `lib/mistral.ex` — Facade (replaces `OpenAI`)
- `lib/mistral/api.ex` — HTTP client (La Plateforme)
- `lib/mistral/api/config.ex` — NimbleOptions config schema
- `lib/mistral/api/error_response.ex` — implements `MusicLibrary.ErrorResponse`
- `lib/mistral/completion.ex` — Struct for non-streaming completions
- `test/mistral_test.exs` — Facade tests
- `test/mistral/api_test.exs` — API tests
- `test/support/fixtures/mistral_fixtures.ex` — Response fixtures

### Files to modify

- `lib/music_library/chats/record_chat.ex` — `OpenAI.chat_stream` → `Mistral.chat_stream`; potentially add BraveSearch injection
- `lib/music_library/chats/artist_chat.ex` — same
- `lib/music_library/chats/collection_chat.ex` — same
- `lib/music_library/records/similarity.ex` — `OpenAI.embeddings` → `Mistral.embeddings`
- `lib/music_library/records/enrichment.ex` — `OpenAI.gpt` → `Mistral.gpt`
- `lib/music_library/retry_delay.ex` — Add Mistral reset header parsing
- `lib/music_library/worker/error_handler.ex` — Add `Mistral.API.ErrorResponse` to `@error_structs`
- `config/config.exs` — Replace OpenAI config with Mistral
- `config/runtime.exs` — Read `MISTRAL_API_KEY` env var
- `config/test.exs` — Stub `Mistral.API` via `Req.Test`

### Files to remove

- `lib/open_ai.ex`
- `lib/open_ai/api.ex`
- `lib/open_ai/api/config.ex`
- `lib/open_ai/api/error_response.ex`
- `lib/open_ai/completion.ex`
- `test/open_ai_test.exs`
- `test/open_ai/api_test.exs`

---

## Migration Risk Matrix

| Risk                                            | Severity | Mitigation                                                               |
| ----------------------------------------------- | -------- | ------------------------------------------------------------------------ |
| Web search feature gap (if using La Plateforme) | High     | Pre-fetch via BraveSearch, inject as context; or use Studio Agents API   |
| Two-API-surface complexity (if using Studio)    | High     | Start with La Plateforme only; add Studio later if needed                |
| Chat quality regression                         | Medium   | Compare responses side-by-side; keep OpenAI key active during transition |
| Embedding dimension mismatch                    | Medium   | Full re-embed via existing batch worker; verify similarity results       |
| Rate limit header format                        | Low      | Test with actual Mistral 429 responses; adjust header parsing            |
| Model prompt compatibility                      | Medium   | System prompts may need tuning for Mistral models                        |

---

## Estimated Effort (Option A: La Plateforme with BraveSearch injection)

| Task                                                    | Hours                       |
| ------------------------------------------------------- | --------------------------- |
| Create Mistral module tree (facade, API, config, error) | 3-4                         |
| Rewrite SSE event decoder for Chat Completions format   | 2-3                         |
| Web search via BraveSearch injection into chat context  | 3-4                         |
| Update 5 call sites (chat × 3, embeddings, genres)      | 1-2                         |
| Error handling + RetryDelay updates                     | 1                           |
| Config changes (3 files)                                | 0.5                         |
| Tests: new + update existing                            | 3-4                         |
| Regenerate all embeddings                               | (automated, no manual work) |
| Integration testing (chat quality, similarity)          | 2-3                         |
| Documentation update (architecture doc)                 | 0.5                         |
| **Total**                                               | **~16-24 hours**            |

## References

- [Mistral Websearch Docs](https://docs.mistral.ai/studio-api/agents/agent-tools/websearch) — Studio Agents API web search tool (`web_search` / `web_search_premium`)
- [Mistral Chat Completions API](https://docs.mistral.ai/api/) — La Plateforme chat completions (no web search)
- [Mistral Embeddings](https://docs.mistral.ai/api/#tag/embeddings) — La Plateforme embeddings endpoint
