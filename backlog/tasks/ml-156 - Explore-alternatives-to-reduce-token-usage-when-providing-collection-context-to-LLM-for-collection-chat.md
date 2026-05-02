---
id: ML-156
title: >-
  Explore alternatives to reduce token usage when providing collection context
  to LLM for collection chat
status: To Do
assignee: []
created_date: '2026-05-02 16:02'
updated_date: '2026-05-02 16:13'
labels:
  - chat
  - collection
  - openai
  - token-optimization
dependencies: []
references:
  - 'backlog://document/doc-1'
documentation:
  - lib/music_library/chats/collection_chat.ex
  - lib/music_library/collection.ex
  - lib/music_library/chats/prompt.ex
  - lib/music_library/chats/stream_provider.ex
  - lib/open_ai/api.ex
  - lib/music_library_web/components/chat.ex
  - lib/music_library_web/live/collection_live/index.ex
priority: high
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Currently, every new collection chat sends the ENTIRE collection catalog (all records formatted as "Artist - Title (year, format) [genres]") plus aggregated stats as the `instructions` parameter to the OpenAI Responses API. For a collection of 500+ records, this burns ~9,000+ input tokens on EVERY new chat start — regardless of what the user asks.

The goal of this task is to analyze alternatives, pick the best one, and implement it. The selected approach should:
- Significantly reduce per-chat token usage
- Preserve or improve the quality of LLM responses about the collection
- Not require architectural overhauls beyond the chat/streaming layer

The `Collection.collection_summary/0` function loads ALL records from the DB, formats them, and returns `{summary, count}`. This is computed asynchronously in `CollectionLive.Index.mount/3` and passed to the Chat component as `chat_context`. `CollectionChat.build_instructions/2` then embeds the full summary into the instructions string sent to OpenAI.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `CollectionChat.build_instructions/2` no longer interpolates the full collection catalog into the instructions sent to OpenAI — only aggregated stats and a record count are included
- [ ] #2 A `file_search` tool with the collection's vector store ID is included in every collection chat request to the OpenAI Responses API
- [ ] #3 A `CollectionChat.FileStore` module manages the collection file lifecycle: upload to OpenAI Files API, vector store creation, and file-to-store attachment, persisting IDs via `Secrets`
- [ ] #4 When a record is added, edited, or deleted, the collection file at OpenAI is refreshed (async, non-blocking) so the LLM always searches up-to-date data
- [ ] #5 If the file/vector store is unavailable (upload failed, first deploy), the chat falls back to stats-only instructions without errors
- [ ] #6 Existing record and artist chats continue to work without changes (no regression in streaming)
- [ ] #7 Tests cover: Files API endpoints, file upload/create/refresh lifecycle, `file_search` tool inclusion in chat requests, fallback when file store is unavailable, empty collection edge case
- [ ] #8 Per-chat input tokens for the collection chat instructions are O(1) relative to collection size (the file is searched by OpenAI on demand, not embedded in instructions)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Approach: OpenAI `file_search` tool

Upload the collection catalog as a file to OpenAI, create a vector store, and use the Responses API's built-in `file_search` tool. OpenAI automatically performs semantic search over the file and includes relevant results inline in the response stream — no SSE event handling changes, no orchestration loop.

Token savings: ~9,000 → ~100 tokens per chat (99% reduction). File search results consume ~200-500 tokens only when the model actually searches.

Research and alternative analysis: see [ML-156 Research document](backlog://document/doc-1).

---

### Phase 1: OpenAI API extensions

Add to `OpenAI.API` (following existing `new_request/1` pattern with `Req.RateLimiter` on `:open_ai` bucket):

- `upload_file(file_content, config)` — `POST /v1/files` with multipart body, `purpose: "assistants"`
- `create_vector_store(name, config)` — `POST /v1/vector_stores`
- `add_file_to_vector_store(store_id, file_id, config)` — `POST /v1/vector_stores/{id}/files`
- `delete_file(file_id, config)` — `DELETE /v1/files/{id}` (cleanup on re-upload)

~60 lines.

### Phase 2: File management module

Create `MusicLibrary.Chats.CollectionChat.FileStore`:

```
defmodule MusicLibrary.Chats.CollectionChat.FileStore do
  @moduledoc """
  Manages the collection catalog file lifecycle at OpenAI.
  Persists file_id and vector_store_id via Secrets.
  """

  @spec ensure_uploaded() :: {:ok, String.t()} | {:error, term()}
  def ensure_uploaded do
    # Check Secrets for existing file_id + vector_store_id
    # If missing, call Collection.collection_summary/0
    # Upload to OpenAI, create vector store, attach file
    # Persist IDs via Secrets.store/2
    # Return {:ok, vector_store_id}
  end

  @spec refresh() :: :ok | {:error, term()}
  def refresh do
    # Delete old file from OpenAI (if exists)
    # Regenerate summary, upload new file
    # Attach to existing vector store (re-indexes automatically)
  end

  @spec get_vector_store_id() :: {:ok, String.t()} | {:error, :not_uploaded}
  def get_vector_store_id do
    # Read vector_store_id from Secrets
  end
end
```

- `ensure_uploaded/0` — lazy init on first chat; idempotent
- `refresh/0` — called when records are added/edited/deleted (async, non-blocking)
- `get_vector_store_id/0` — reads from `Secrets`; returns error if never uploaded

~50 lines.

### Phase 3: Chat streaming changes

**`OpenAI.chat_stream/2`** — add optional `vector_store_ids` option:

```elixir
def chat_stream(messages, opts) do
  model = Keyword.get(opts, :model, "gpt-4.1")
  vector_store_ids = Keyword.get(opts, :vector_store_ids, [])
  
  tools = [%{type: "web_search_preview"}]
  tools = if vector_store_ids != [],
    do: [%{type: "file_search", vector_store_ids: vector_store_ids} | tools],
    else: tools
  
  # ... rest unchanged
end
```

**`OpenAI.API.chat_stream/6`** — accept tools as parameter instead of hardcoding (or add `tools` parameter):

```elixir
def chat_stream(messages, instructions, model, temperature, config, cb, tools \\ nil) do
  tools = tools || [%{type: "web_search_preview"}]
  # ... use tools in json body
end
```

**`CollectionChat.stream_response/3`:**

```elixir
def stream_response(messages, {_summary, record_count}, callback) do
  instructions = build_instructions(record_count)
  
  vector_store_opts = case FileStore.get_vector_store_id() do
    {:ok, id} -> [vector_store_ids: [id]]
    {:error, _} -> []  # fall back to stats-only
  end
  
  OpenAI.chat_stream(messages, [
    on_chunk: callback,
    instructions: instructions,
    model: "gpt-5.1"
  ] ++ vector_store_opts)
end
```

~15 lines.

### Phase 4: Prompt changes

Update `CollectionChat.build_instructions/2`:

```elixir
defp build_instructions(record_count) do
  Prompt.build("""
  Answer questions about the user's music collection.
  The collection contains #{record_count} records.
  Use file search to find specific records when the user asks about \
  artists, albums, genres, or formats in their collection.

  # Mentioning artists/albums

  **IF YOU MENTION AN ARTIST NAME OR ALBUM NAME, wrap it in "[[name]]", \
  for example "[[Steven Wilson]]"
  """)
end
```

Key changes:
- Remove `#{collection_summary}` interpolation entirely
- Remove `Collection catalog:` section
- Remove `Use the provided collection catalog as your primary reference`
- Add guidance to use file search for specific record lookup
- `stream_response/3` signature changes from `{summary, count}` to just `count` (summary only used for stats, which we no longer pass)

~10 lines.

### Phase 5: Trigger refresh on collection changes

In `CollectionLive.Index`, handle record add/edit/delete events:

```elixir
# In handle_info for RecordForm saved / AddRecord imported / delete:
def handle_info({MusicLibraryWeb.Components.RecordForm, {:saved, _record}}, socket) do
  Task.start(&MusicLibrary.Chats.CollectionChat.FileStore.refresh/0)
  IndexActions.handle_record_saved(socket)
end
```

Or use the existing PubSub topic `"records:#{id}"` to trigger refresh from a central place. Debounce rapid changes (multiple quick adds) with a short timer.

~20 lines.

### Phase 6: Testing

- `test/open_ai/api_test.exs` — test `upload_file`, `create_vector_store`, `add_file_to_vector_store`, `delete_file` endpoints via `Req.Test` stubs
- `test/music_library/chats/collection_chat/file_store_test.exs` — test `ensure_uploaded` (first-time upload), `refresh` (re-upload), `get_vector_store_id` (missing, present), and `Secrets` persistence
- `test/music_library/chats/collection_chat_test.exs` — verify instructions no longer contain catalog; verify `file_search` tool included when vector store is available; verify fallback to stats-only when unavailable
- `test/music_library/collection_test.exs` — existing `collection_summary/0` tests continue to pass unchanged

Estimated total: ~150 lines across 5-6 files. Low risk — no changes to core streaming infrastructure.
<!-- SECTION:PLAN:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [ ] #1 All new and modified modules have @moduledoc
- [ ] #2 All public functions have @spec and @doc
- [ ] #3 Mix compile --warnings-as-errors passes
- [ ] #4 mix test passes with no failures
- [ ] #5 mix format --check-formatted passes
- [ ] #6 mix credo passes
- [ ] #7 Documentation updated (architecture.md if new modules/schemas added)
- [ ] #8 Commit subject references ML-156
<!-- DOD:END -->
