---
id: ML-156
title: >-
  Explore alternatives to reduce token usage when providing collection context
  to LLM for collection chat
status: To Do
assignee: []
created_date: "2026-05-02 16:02"
updated_date: "2026-05-04 08:19"
labels:
  - ready
dependencies: []
references:
  - "backlog://document/doc-1"
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

## Approach: OpenAI `file_search` tool + Oban-managed file lifecycle

Upload the collection catalog as a file to OpenAI, create a vector store, and use the Responses API's built-in `file_search` tool. OpenAI automatically performs semantic search over the file and includes relevant results inline in the response stream — no SSE event handling changes, no orchestration loop.

Token savings: ~9,000 → ~100 tokens per chat (99% reduction). File search results consume ~200-500 tokens only when the model actually searches.

Research and alternative analysis: see [ML-156 Research document](backlog://document/doc-1).

### Architecture decisions

1. **Chat sessions never upload or refresh files.** They read `vector_store_id` from `Secrets`. If missing, they fall back to stats-only instructions (no errors surfaced to the user).
2. **File upload and refresh happen exclusively in Oban workers.** No `Task.start`, no `start_async` — all OpenAI API calls for file management are serialized through a unique Oban worker with a 5-minute debounce window.
3. **Refresh is triggered at the lowest level.** `Records.create_record/1`, `Records.update_record/2`, and `Records.delete_record/1` enqueue the refresh worker on success. This catches all mutation paths (Index, Show, cart import, barcode scan, batch operations) without PubSub or LiveView-specific hooks.
4. **The full `collection_summary/0` (catalog + stats) is eliminated from the LiveView page load.** `CollectionLive.Index.mount/3` loads only a lightweight `stats_summary/0` — the same aggregated stats (record count, artist count, genre/format/era breakdowns) but without the per-record catalog lines. The full catalog is only loaded inside the Oban worker when a file upload/refresh is needed. Stats are ~200 tokens, always included in instructions, giving the LLM high-level collection awareness even before file search.

---

### Phase 1: OpenAI API extensions (7 new endpoints)

Add to `OpenAI.API` (following existing `new_request/1` pattern with `Req.RateLimiter` on `:open_ai` bucket):

- `upload_file(file_content, filename, config)` — `POST /v1/files` with multipart body (`purpose: "assistants"`, `file` field containing the catalog text). Uses `Req` multipart support.
- `create_vector_store(name, config)` — `POST /v1/vector_stores` with `%{name: name}` body.
- `add_file_to_vector_store(store_id, file_id, config)` — `POST /v1/vector_stores/{store_id}/files` with `%{file_id: file_id}` body.
- `remove_file_from_vector_store(store_id, file_id, config)` — `DELETE /v1/vector_stores/{store_id}/files/{file_id}`. Detaches the old file from the vector store before deleting.
- `delete_file(file_id, config)` — `DELETE /v1/files/{file_id}`. Called after detaching from vector store.
- `get_file(file_id, config)` — `GET /v1/files/{file_id}`. Returns file metadata including `status` field (`uploaded`, `processed`, `error`). Used to poll indexing completion after attach.
- `list_files(config)` — `GET /v1/files`. Returns paginated list of files. Used by the periodic cleanup worker to find orphaned resources.

~90 lines.

---

### Phase 2: FileStore module

Create `MusicLibrary.Chats.CollectionChat.FileStore`:

```elixir
defmodule MusicLibrary.Chats.CollectionChat.FileStore do
  @moduledoc """
  Manages the collection catalog file lifecycle at OpenAI.
  Persists file_id and vector_store_id via Secrets.

  All OpenAI API calls happen inside Oban workers — never from chat
  sessions or LiveViews. The chat session path only calls get_vector_store_id/0.
  """

  @spec upload_or_refresh() :: :ok | {:error, term()}
  def upload_or_refresh do
    # 1. Check Secrets for existing file_id + vector_store_id
    # 2. If missing → initial upload flow:
    #    a. Call Collection.collection_summary/0 to get catalog text
    #    b. POST /v1/files → file_id
    #    c. POST /v1/vector_stores → vector_store_id
    #    d. POST /v1/vector_stores/{id}/files → attach
    #    e. Poll GET /v1/files/{file_id} until status == "processed"
    #       (max 10 attempts, 2s backoff)
    #    f. Persist both IDs via Secrets.store/2
    # 3. If present → refresh flow:
    #    a. Call Collection.collection_summary/0
    #    b. POST /v1/files → new_file_id
    #    c. POST /v1/vector_stores/{store_id}/files → attach new file
    #    d. Poll GET /v1/files/{new_file_id} until status == "processed"
    #    e. DELETE /v1/vector_stores/{store_id}/files/{old_file_id} → detach old
    #    f. DELETE /v1/files/{old_file_id} → delete old file
    #    g. Update file_id in Secrets (vector_store_id unchanged)
    # 4. Log errors at each step; return :ok or {:error, reason}
  end

  @spec get_vector_store_id() :: {:ok, String.t()} | {:error, :not_uploaded}
  def get_vector_store_id do
    # Read vector_store_id from Secrets
    # Return {:ok, id} or {:error, :not_uploaded}
  end

  @spec cleanup_orphaned_files() :: :ok
  def cleanup_orphaned_files do
    # Called by periodic cleanup worker
    # 1. Read known file_id + vector_store_id from Secrets
    # 2. Call GET /v1/files to list all files
    # 3. Delete any file whose id doesn't match the known file_id
    #    (with safety check: also detach from any vector store first)
    # 4. Log orphan count, return :ok
  end
end
```

Key design properties:

- `upload_or_refresh/0` is the single entry point called by the Oban worker — never by chat sessions
- `get_vector_store_id/0` is the single entry point called by chat sessions — read-only, no side effects
- `cleanup_orphaned_files/0` is a safety net for edge cases (e.g., Secrets write failed after OpenAI upload succeeded)

~70 lines.

---

### Phase 3: Oban workers

#### 3a. RefreshCollectionFile worker

Create `MusicLibrary.Worker.RefreshCollectionFile`:

```elixir
defmodule MusicLibrary.Worker.RefreshCollectionFile do
  use Oban.Worker,
    queue: :default,
    unique: [period: 300, keys: [:worker]],
    max_attempts: 3

  @impl true
  def perform(_job) do
    case MusicLibrary.Chats.CollectionChat.FileStore.upload_or_refresh() do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
```

- `unique: [period: 300, keys: [:worker]]` — 5-minute debounce window. Only one refresh can be executing or scheduled at a time. Rapid record mutations (cart import of 50 records) each call `Oban.insert` but only the first insert succeeds; subsequent inserts within the 300s unique window are silently ignored by Oban.
- `max_attempts: 3` — transient OpenAI failures get 2 retries.
- Queue `:default` (concurrency 10) — the worker is fast (a few API calls), no need for a dedicated queue.

Enqueued from two places:

1. **Record mutations** — `Records.create_record/1`, `update_record/2`, `delete_record/1` (see Phase 4)
2. **Cron** — every hour in both dev and prod, to handle initial upload after deploy and recovery after failures:

```elixir
# config/prod.exs (add to crontab)
{"0 * * * *", MusicLibrary.Worker.RefreshCollectionFile}

# config/dev.exs (add to crontab)
{"*/15 * * * *", MusicLibrary.Worker.RefreshCollectionFile}
```

~15 lines.

#### 3b. CleanupOrphanedOpenAIFiles worker

Create `MusicLibrary.Worker.CleanupOrphanedOpenAIFiles`:

- Cron: monthly (1st of month, 11 AM)
- Calls `FileStore.cleanup_orphaned_files/0`
- Queue: `:default`
- `max_attempts: 2`

~12 lines.

---

### Phase 4: Records context + Collection context + LiveView changes

#### 4a. Records context — enqueue refresh on mutations

In `lib/music_library/records.ex`, after each successful mutation, enqueue the refresh worker **outside** the `with` chain (non-blocking — the mutation succeeds regardless of enqueue result):

```elixir
def create_record(attrs \\ %{}) do
  with {:ok, record} <- do_create_record(attrs),
       record = Enrichment.best_effort_extract_colors(record),
       :ok <- refresh_artist_info_async(record) do
    enqueue_collection_file_refresh()
    {:ok, record}
  end
end

def update_record(%Record{} = record, attrs) do
  with {:ok, updated_record} <- do_update_record(record, attrs),
       :ok <- refresh_artist_info_async(updated_record) do
    enqueue_collection_file_refresh()
    {:ok, updated_record}
  end
end

def delete_record(%Record{} = record) do
  with {:ok, record} <- Repo.delete(record) do
    record
    |> Record.artist_ids()
    |> Enum.each(fn artist_id ->
      Artists.prune_artist_info_async(artist_id)
    end)

    enqueue_collection_file_refresh()
    {:ok, record}
  end
end

defp enqueue_collection_file_refresh do
  %{} |> MusicLibrary.Worker.RefreshCollectionFile.new() |> Oban.insert()
end
```

- `Oban.insert/1` (not `insert!`) — failures to enqueue are silently ignored; the hourly cron acts as a safety net.
- The enqueue happens after the `with` succeeds, ensuring we only refresh when data actually changed.
- All mutation paths are covered: single create (AddRecord, barcode scan), cart import (batch creates via `ImportFromMusicbrainzReleaseGroup` worker, which calls `create_record/1` internally), edit (Index and Show), delete.

~15 lines.

#### 4b. Collection context — add `stats_summary/0` and `count_records/0`

Add to `lib/music_library/collection.ex`:

```elixir
@spec count_records() :: non_neg_integer()
def count_records do
  from(r in Record, where: not is_nil(r.purchased_at))
  |> Repo.aggregate(:count)
end

@spec stats_summary() :: {String.t(), non_neg_integer()}
def stats_summary do
  # Same record load as collection_summary/0 (the heavy SQL query),
  # but only computes the stats header — NO per-record catalog formatting.
  # Returns {stats_string, group_count}.
  # Example stats_string:
  #   "# Stats: 500 releases, 200 artists\nGenres: rock 150, ...\nFormats: ...\nEras: ..."
  records = from(r in Record, where: not is_nil(r.purchased_at), select: ^essential_fields()) |> Repo.all()
  groups = records |> Enum.group_by(& &1.musicbrainz_id)
  stats = build_stats(records, length(groups))
  {stats, length(groups)}
end
```

~10 lines. `collection_summary/0` remains in the module — it's now only called by `FileStore.upload_or_refresh/0` (inside the Oban worker) to generate the catalog text for file upload. `stats_summary/0` extracts the lightweight stats portion for the LiveView to load (still a full table scan, but skips the expensive per-record string formatting — ~200 tokens of output vs ~9,000).

#### 4c. CollectionLive.Index — load stats instead of full catalog

Replace the heavy `start_async(:collection_summary, &Collection.collection_summary/0)` with `stats_summary`:

```elixir
# In mount/3:
|> assign(:collection_stats, {"", 0})
|> start_async(:collection_stats, fn -> Collection.stats_summary() end)

# Rename handle_async:
def handle_async(:collection_stats, {:ok, stats}, socket) do
  {:noreply, assign(socket, :collection_stats, stats)}
end

def handle_async(:collection_stats, {:exit, _reason}, socket) do
  {:noreply, socket}
end

# In the template — pass stats as chat_context:
chat_context={@collection_stats}
```

The `@collection_summary` assign is removed. The Chat component receives `{stats_string, record_count}`, matching the existing tuple shape so no Chat component changes are needed.

~8 lines (mostly renames).

---

### Phase 5: Chat streaming changes

#### 5a. OpenAI facade — accept `:vector_store_ids` option

Modify `OpenAI.chat_stream/2` to pass tools to the API layer:

```elixir
def chat_stream(messages, opts) when is_list(messages) do
  model = Keyword.get(opts, :model, "gpt-4.1")
  temperature = Keyword.get(opts, :temperature, 0.7)
  instructions = Keyword.get(opts, :instructions, "")
  on_chunk = Keyword.fetch!(opts, :on_chunk)
  vector_store_ids = Keyword.get(opts, :vector_store_ids, [])

  tools = build_tools(vector_store_ids)

  API.chat_stream(messages, instructions, model, temperature, open_ai_config(), on_chunk, tools)
end

defp build_tools([]), do: [%{type: "web_search_preview"}]
defp build_tools(ids) when is_list(ids) do
  [%{type: "file_search", vector_store_ids: ids}, %{type: "web_search_preview"}]
end
```

~10 lines.

#### 5b. OpenAI.API — accept optional tools parameter

Add a 7-arity overload to `API.chat_stream`:

```elixir
def chat_stream(messages, instructions, model, temperature, config, cb) do
  chat_stream(messages, instructions, model, temperature, config, cb, [%{type: "web_search_preview"}])
end

def chat_stream(messages, instructions, model, temperature, config, cb, tools) when is_list(tools) do
  config
  |> new_request()
  |> Req.merge(
    url: "/v1/responses",
    receive_timeout: 60_000,
    connect_options: [timeout: 5_000],
    json: %{
      model: model,
      instructions: instructions,
      input: messages,
      tools: tools,
      stream: true,
      temperature: temperature
    },
    into: :self
  )
  |> do_chat_stream(cb)
end
```

- Uses function clause pattern matching (`when is_list(tools)`) rather than default argument with `||`, avoiding the falsy-empty-list pitfall.
- The 6-arity version is preserved for backward compatibility (existing RecordChat and ArtistChat callers).

~5 lines.

#### 5c. CollectionChat — new instructions and streaming logic

Update `CollectionChat`:

```elixir
@impl true
def stream_response(messages, {stats, record_count}, callback) do
  instructions = build_instructions(stats, record_count)

  vector_store_opts =
    case FileStore.get_vector_store_id() do
      {:ok, id} -> [vector_store_ids: [id]]
      {:error, :not_uploaded} -> []  # fall back to stats-only
    end

  OpenAI.chat_stream(messages, [
    on_chunk: callback,
    instructions: instructions,
    model: "gpt-5.1"
  ] ++ vector_store_opts)
end

defp build_instructions(stats, record_count) do
  Prompt.build("""
  Answer questions about the user's music collection.
  Use the provided stats and file search to answer questions
  about the collection.

  #{stats}

  The collection contains #{record_count} records in total.

  Use file search to find specific records when the user asks about
  artists, albums, genres, or formats in their collection.

  If file search returns no results for a query, say so honestly —
  don't guess or invent records. If you're unsure whether a record
  exists, mention that it wasn't found in the collection.

  # Mentioning artists/albums

  **IF YOU MENTION AN ARTIST NAME OR ALBUM NAME, wrap it in "[[name]]",
  for example "[[Steven Wilson]]"
  """)
end
```

Key changes from current code:

- `stream_response/3` keeps the `{tuple, count}` signature shape — the stats string replaces the catalog text
- `build_instructions/2` interpolates aggregated stats (~200 tokens) instead of the full catalog (~9,000 tokens)
- `FileStore.get_vector_store_id/0` is the only FileStore function called from the chat path
- On `{:error, :not_uploaded}`, vector_store_opts is empty → `build_tools([])` returns only `web_search_preview` → stats-only fallback (still useful for aggregate questions)
- Added explicit guidance for when file search returns no results
- The "Collection catalog:" section is removed; replaced with stats inline

~18 lines (modifications to existing code).

---

### Phase 6: Testing

#### 6a. OpenAI.API endpoint tests (`test/open_ai/api_test.exs`)

Add test blocks for the 7 new endpoints, following existing `Req.Test.stub` patterns:

- `upload_file/3` — verify multipart body includes `purpose: "assistants"` and file content; test success (200 + file JSON) and error (500) responses
- `create_vector_store/2` — verify request body has `name` field; test success and error
- `add_file_to_vector_store/3` — verify URL path includes store_id; test success and error
- `remove_file_from_vector_store/3` — verify DELETE request; test 200 and 404 (already removed)
- `delete_file/2` — verify DELETE request; test success
- `get_file/2` — test `status: "processed"` (success), `status: "uploaded"` (still processing), and error
- `list_files/1` — test paginated response with file list
- Rate-limit error handling (429 → `ErrorResponse` with `:rate_limit` kind) for each endpoint

~80 lines.

#### 6b. FileStore tests (`test/music_library/chats/collection_chat/file_store_test.exs`)

Test `FileStore` functions with `Req.Test` stubs and direct `Secrets` manipulation:

- `upload_or_refresh/0` — first-time upload (no secrets → creates file + store + attaches → secrets populated)
- `upload_or_refresh/0` — refresh (secrets present → uploads new file → attaches → detaches old → deletes old → updates file_id in secrets)
- `upload_or_refresh/0` — handles file still "uploaded" (polls until "processed")
- `upload_or_refresh/0` — handles OpenAI API errors gracefully (returns `{:error, ...}`)
- `get_vector_store_id/0` — returns `{:ok, id}` when secret exists
- `get_vector_store_id/0` — returns `{:error, :not_uploaded}` when secret missing
- `cleanup_orphaned_files/0` — deletes files not matching known file_id; skips known file

~70 lines.

#### 6c. CollectionChat tests (`test/music_library/chats/collection_chat_test.exs`)

Update existing tests and add new ones:

- Verify instructions **no longer** contain the per-record catalog lines (the key regression test)
- Verify instructions **do** contain the aggregated stats string and record count
- Verify `file_search` tool is included in the API request body when vector store is available (stub `FileStore.get_vector_store_id/0` → `{:ok, "vs_test"}` and assert `tools` array in the JSON body contains `%{"type" => "file_search", "vector_store_ids" => ["vs_test"]}`)
- Verify `file_search` tool is **not** included when vector store is unavailable (stub → `{:error, :not_uploaded}`, assert tools only has `web_search_preview`)
- Verify `web_search_preview` is always included regardless of file_search presence
- Test empty collection edge case (stats = "", record_count = 0)
- Test SSE event handling: include `response.file_search_call.in_progress`, `response.file_search_call.searching`, and `response.file_search_call.completed` events in the test stream fixture to verify they're silently consumed (caught by the `"response." <> _` catch-all) without breaking the stream

~60 lines (modifications to existing + new tests).

#### 6d. Worker tests (`test/music_library/worker/refresh_collection_file_test.exs`)

- `perform/1` delegates to `FileStore.upload_or_refresh/0` and returns `:ok`
- `perform/1` returns `{:error, reason}` on failure
- Unique constraint: inserting two jobs within 300s results in only one executing (test with `Oban.insert/1` returning `{:ok, _}` for first and `{:ok, %{conflict?: true}}` for second)

~20 lines.

#### 6e. Records context integration tests

In existing `test/music_library/records_test.exs` (or equivalent):

- `create_record/1` enqueues `RefreshCollectionFile` worker
- `update_record/2` enqueues `RefreshCollectionFile` worker
- `delete_record/1` enqueues `RefreshCollectionFile` worker
- Verify with `assert_enqueued` (Oban testing helper)

~15 lines.

#### 6f. LiveView test

In `test/music_library_web/live/collection_live/index_test.exs` (or equivalent):

- Verify `@collection_stats` is set after mount (not `@collection_summary`)
- Verify Chat component receives `{stats_string, count}` tuple as `chat_context`

~8 lines (modifications to existing test).

#### 6g. Collection context tests

In existing `test/music_library/collection_test.exs` (or equivalent):

- `stats_summary/0` returns stats string with genre/format/era breakdowns and correct group count
- `stats_summary/0` returns `{"", 0}` for empty collection
- `count_records/0` returns correct count
- Existing `collection_summary/0` tests continue to pass unchanged

~20 lines.

Estimated total: ~510 lines across 13-15 files. Risk: low/medium — the core streaming infrastructure (`decode_responses_event/2`, Chat component `do_send_message/2`, SSE event loop) is untouched. New code is additive (API endpoints, Oban worker, FileStore module) and follows existing patterns.

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
