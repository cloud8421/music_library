---
id: ML-156
title: >-
  Explore alternatives to reduce token usage when providing collection context
  to LLM for collection chat
status: To Do
assignee: []
created_date: "2026-05-02 16:02"
updated_date: "2026-05-22 22:40"
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
  - docs/architecture.md
  - docs/production-infrastructure.md
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
- [ ] #9 Refresh scheduling uses a true debounce/coalescing strategy so rapid/bulk mutations and mutations during an executing refresh cannot leave the active file stale
- [ ] #10 FileStore only switches the active vector store after vector-store-file indexing succeeds; failed refreshes keep the previous active store available
- [ ] #11 Production documentation includes OpenAI file_search/vector-store cost profile, initial refresh behavior, cleanup/rollback notes, and whether new environment variables are required
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Approach: OpenAI `file_search` tool + Oban-managed collection catalog lifecycle

Upload the collection catalog to OpenAI, index it in a vector store, and include the Responses API `file_search` tool in collection chat requests. Keep only aggregated stats and record count in the prompt instructions. This makes per-chat instructions O(1) relative to collection size while preserving the ability to answer record-specific questions through retrieval.

Research and alternative analysis: see [ML-156 Research document](backlog://document/doc-1).

### Why this approach

- **Stats-only** is much simpler, but it removes record-specific collection awareness.
- **Custom function calling** would avoid OpenAI file storage, but requires a streaming tool-call orchestration loop and changes shared chat streaming code for all chat types.
- **Local RAG with SQLite FTS/sqlite-vec** avoids external vector-store lifecycle, but still requires retrieval orchestration before/inside every chat request and would either be mostly lexical or depend on the existing embedding pipeline being complete and fresh. It remains a good future option if OpenAI file_search quality/cost is poor.
- **OpenAI file_search** gives semantic retrieval with minimal streaming changes: file-search events are `response.*` events and can be ignored by the existing catch-all while output text streams normally.

### Performance and cost profile

- **Per chat:** instructions contain stats + count only (~100-300 tokens), not the full catalog (~9,000+ tokens for ~500 records). File-search result tokens are paid only when the model searches.
- **Per refresh:** catalog generation, upload, and indexing are O(collection size). This is moved out of LiveView/chat paths and into debounced Oban jobs.
- **Page load:** `CollectionLive.Index` loads a stats-only context, not the full catalog. Measure `stats_summary/0` once on realistic data; if it is noticeably slow, switch it from in-memory grouping to SQL aggregate queries.
- **Hash skip:** store a SHA-256 hash of the uploaded catalog. Cron/manual refreshes skip upload/index work when the catalog content is unchanged.
- **Benchmarks:** no recurring benchmark is required. Do one implementation-time measurement comparing before/after instruction byte/token estimates for representative collection sizes (current data, 1,000 records if easy to synthesize) and record catalog refresh runtime.
- **Paid resources:** document current OpenAI pricing at implementation time in `docs/production-infrastructure.md` because prices change. Expected profile for current scale is negligible storage for a small text file/vector store plus occasional indexing after debounced mutations, and per-chat retrieval/tool charges only when file_search runs.

### Architecture decisions

1. **Chat sessions never upload or refresh files.** They only read the active vector store ID from `FileStore.get_vector_store_id/0`. Missing/unavailable store falls back to stats-only instructions without surfacing an error to the user.
2. **Use a new vector store per successful refresh.** Build and index the new file/store off to the side, then switch the active secret only after vector-store-file indexing completes. Failed refreshes leave the previous active store untouched.
3. **Persist FileStore state as one JSON secret.** Store `%{file_id, vector_store_id, catalog_hash, updated_at}` in a single encrypted `Secrets` entry to avoid partial multi-secret updates. `get_vector_store_id/0` only returns `{:ok, id}` when the state contains a usable active file and vector store.
4. **True debounce/coalescing.** Record mutations schedule a refresh for 5 minutes in the future. Additional mutations while a refresh is scheduled replace `scheduled_at`, pushing the refresh out. Mutations that happen while a worker is already executing can schedule a follow-up refresh, so no changes are dropped.
5. **Refresh triggers cover all catalog-affecting mutations.** CRUD paths enqueue refreshes, and direct enrichment `Repo.update` paths that affect catalog content (notably genres and any title/artist/release-date/format/purchased-state changes) either go through `Records.update_record/2` or explicitly enqueue on success.
6. **OpenAI API work uses an `:open_ai` Oban queue.** Add a serialized queue (`open_ai: 1`) for OpenAI-calling workers, in addition to the existing Req rate limiter.
7. **Cleanup is scoped and safe.** Only delete OpenAI files/vector stores with the ML-managed name/filename prefix, and never delete unrelated OpenAI resources.

---

### Phase 0: Baseline measurement and API documentation check

Before implementing:

1. Confirm current OpenAI Responses API `file_search`, Files, and Vector Stores endpoint shapes.
2. Confirm the status values for vector-store file indexing and poll the vector-store-file endpoint, not the generic file metadata endpoint.
3. Record a one-off baseline:
   - current collection chat instruction byte length / estimated tokens;
   - expected stats-only instruction byte length / estimated tokens;
   - current `Collection.collection_summary/0` runtime on realistic data.

Do not add a permanent benchmark unless this measurement shows refresh/page-load costs are high enough to justify ongoing tracking.

---

### Phase 1: OpenAI API extensions

Add public functions to `OpenAI.API` following the existing `new_request/1` pattern, Req rate limiting, and `OpenAI.API.ErrorResponse.from_response/1` error handling:

- `upload_file(file_content, filename, config)` — `POST /v1/files` with multipart body (`purpose: "assistants"`, file text content).
- `create_vector_store(name, config)` — `POST /v1/vector_stores` with an ML-managed name such as `music-library-collection-chat-<timestamp>-<hash>`.
- `add_file_to_vector_store(vector_store_id, file_id, config)` — `POST /v1/vector_stores/{vector_store_id}/files`.
- `get_vector_store_file(vector_store_id, file_id, config)` — `GET /v1/vector_stores/{vector_store_id}/files/{file_id}`. Use this for indexing status polling.
- `delete_vector_store(vector_store_id, config)` — `DELETE /v1/vector_stores/{vector_store_id}` for cleanup/rollback.
- `delete_file(file_id, config)` — `DELETE /v1/files/{file_id}`.
- `list_files(config)` — `GET /v1/files`, used by scoped cleanup.
- `list_vector_stores(config)` — `GET /v1/vector_stores`, used by scoped cleanup.
- Add `remove_file_from_vector_store/3` only if the confirmed API flow requires detach without deleting the whole old vector store.

Keep the existing 6-arity `chat_stream/6` intact and add a 7-arity `chat_stream/7` that accepts a tools list.

---

### Phase 2: Collection context changes

Add lightweight collection context functions:

```elixir
@spec count_records() :: non_neg_integer()
def count_records

@spec stats_summary() :: {String.t(), non_neg_integer()}
def stats_summary

@spec file_search_catalog() :: {String.t(), non_neg_integer(), String.t()}
def file_search_catalog
```

- `stats_summary/0` returns `{stats_text, release_group_count}` with no per-record catalog lines. Empty collection returns `{ "", 0 }`.
- `file_search_catalog/0` returns deterministic text for upload plus record count and SHA-256 hash. Include the stats header and per-record lines, ordered deterministically, with only collection records (`purchased_at` not nil).
- Keep any existing `collection_summary/0` tests passing if the function remains. If renamed/extracted, update tests and callers so only FileStore uses the full catalog.
- The LiveView/chat path must never receive the full catalog.

If the one-off measurement shows `stats_summary/0` is too expensive, compute stats with SQL aggregates rather than loading all essential fields.

---

### Phase 3: `CollectionChat.FileStore`

Create `MusicLibrary.Chats.CollectionChat.FileStore` with `@moduledoc`, specs, and public functions:

```elixir
@spec upload_or_refresh() :: :ok | {:error, term()}
def upload_or_refresh

@spec get_vector_store_id() :: {:ok, String.t()} | {:error, :not_uploaded}
def get_vector_store_id

@spec cleanup_orphaned_resources() :: :ok | {:error, term()}
def cleanup_orphaned_resources
```

#### Active-state secret

Use one encrypted secret value, JSON-encoded, for example under `collection_chat_file_store`:

```json
{
  "file_id": "file_...",
  "vector_store_id": "vs_...",
  "catalog_hash": "sha256...",
  "updated_at": "2026-05-22T...Z"
}
```

#### Upload/refresh flow

1. Build `{catalog_text, record_count, hash}` via `Collection.file_search_catalog/0`.
2. If `record_count == 0`:
   - delete old active vector store/file best-effort;
   - clear the active FileStore secret;
   - return `:ok` so collection chat falls back to stats-only.
3. Read the active state secret.
4. If active state exists and `catalog_hash == hash`, return `:ok` without OpenAI API calls.
5. Upload a new file with an ML-managed filename prefix and the hash in the name.
6. Create a new vector store with an ML-managed name prefix and the hash/timestamp in the name.
7. Attach the uploaded file to the new vector store.
8. Poll `get_vector_store_file/3` until indexing is complete. Use bounded attempts/backoff; return `{:error, reason}` for failed/cancelled/timeouts.
9. Only after indexing succeeds, persist the new active-state JSON secret.
10. Best-effort delete the previous active vector store and file. Log cleanup failures and rely on the cleanup worker to retry later.

If any step before the active secret switch fails, best-effort delete the newly created resources and return `{:error, reason}`. The old active store remains available to chat users.

#### Read path

`get_vector_store_id/0` is read-only and returns:

- `{:ok, vector_store_id}` only when the active JSON secret has both a `file_id` and `vector_store_id`;
- `{:error, :not_uploaded}` otherwise.

#### Cleanup flow

`cleanup_orphaned_resources/0`:

1. Read the active state.
2. List OpenAI vector stores and files.
3. Select only resources with the ML-managed collection-chat prefix.
4. Delete inactive vector stores first.
5. Delete inactive files.
6. Never delete resources without the ML-managed prefix.

---

### Phase 4: Oban workers and queue config

Add `:open_ai` to Oban queues in `config/config.exs`:

```elixir
queues: [default: 10, heavy_writes: 1, music_brainz: 1, discogs: 1, wikipedia: 1, last_fm: 1, open_ai: 1]
```

Create `MusicLibrary.Worker.RefreshCollectionFile` as a thin wrapper:

```elixir
defmodule MusicLibrary.Worker.RefreshCollectionFile do
  use Oban.Worker,
    queue: :open_ai,
    max_attempts: 3,
    unique: [fields: [:worker], states: [:scheduled], period: :infinity],
    replace: [scheduled: [:scheduled_at]]

  @impl true
  def perform(_job) do
    case MusicLibrary.Chats.CollectionChat.FileStore.upload_or_refresh() do
      :ok -> :ok
      {:error, reason} -> MusicLibrary.Worker.ErrorHandler.to_oban_result(reason)
    end
  end

  @spec enqueue_debounced() :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def enqueue_debounced do
    %{}
    |> new(schedule_in: {5, :minutes})
    |> Oban.insert()
  end
end
```

Important debounce semantics:

- uniqueness checks only `:scheduled` jobs, so mutations during an executing refresh can enqueue a follow-up scheduled refresh;
- `replace: [scheduled: [:scheduled_at]]` means rapid mutations push the single scheduled refresh later instead of first-writer-wins;
- the hourly cron and catalog hash skip provide recovery without repeated uploads.

Create `MusicLibrary.Worker.CleanupOrphanedOpenAICollectionResources`:

- queue `:open_ai`;
- `max_attempts: 2`;
- delegates to `FileStore.cleanup_orphaned_resources/0`;
- routes errors through `Worker.ErrorHandler`.

Cron:

- production: hourly `RefreshCollectionFile` for initial upload/recovery; monthly cleanup after existing monthly jobs;
- development: every 15 minutes for refresh if desired; monthly cleanup can stay production-only unless useful in dev.

---

### Phase 5: Record mutation triggers

Add a shared enqueue helper in the Records context, e.g.:

```elixir
@spec enqueue_collection_file_refresh() :: :ok
def enqueue_collection_file_refresh do
  case MusicLibrary.Worker.RefreshCollectionFile.enqueue_debounced() do
    {:ok, _job} -> :ok
    {:error, reason} ->
      Logger.warning("Failed to enqueue collection file refresh: #{inspect(reason)}")
      :ok
  end
end
```

Use it after successful mutations, non-blocking:

- `Records.create_record/1`
- `Records.update_record/2`
- `Records.delete_record/1`
- enrichment/direct update paths that affect catalog content, especially `Records.Enrichment.populate_genres/1`
- any other direct update path discovered during implementation that changes title, artists, release date, format, genres, MusicBrainz ID, or purchased status.

Do not enqueue on failed changesets/API errors. It is acceptable to enqueue for some harmless non-catalog changes because the FileStore hash skip avoids unnecessary uploads.

---

### Phase 6: LiveView and collection chat changes

#### CollectionLive.Index

Replace full catalog loading:

```elixir
|> assign(:collection_stats, {"", 0})
|> start_async(:collection_stats, fn -> Collection.stats_summary() end)
```

Pass `chat_context={@collection_stats}` to the Chat component. Remove the `@collection_summary` assign from the LiveView path.

#### OpenAI facade/API

Update `OpenAI.chat_stream/2` to accept `:vector_store_ids`:

```elixir
vector_store_ids = Keyword.get(opts, :vector_store_ids, [])
tools = build_tools(vector_store_ids)
API.chat_stream(messages, instructions, model, temperature, open_ai_config(), on_chunk, tools)
```

Build tools as:

- no vector store: `[%{type: "web_search_preview"}]`
- vector store present: `[%{type: "file_search", vector_store_ids: ids}, %{type: "web_search_preview"}]`

Preserve the existing `API.chat_stream/6` behavior for record and artist chats.

#### CollectionChat

`CollectionChat.stream_response/3`:

1. Build instructions from stats + count only.
2. Call `FileStore.get_vector_store_id/0`.
3. Include `vector_store_ids: [id]` only when available.
4. Fall back to stats-only instructions when not uploaded.

Instructions must:

- tell the model to use stats for aggregate questions;
- tell the model to use file search for artists/albums/genres/formats;
- tell the model not to invent records when search returns no results;
- keep the existing `[[artist/album]]` linking rule.

---

### Phase 7: Tests

#### OpenAI.API tests

Add coverage for new endpoints:

- multipart upload includes `purpose: "assistants"`, filename, and file content;
- vector store creation request body/name;
- file-to-vector-store attachment;
- vector-store-file status polling endpoint, including completed, in-progress, and failed statuses;
- delete vector store and delete file;
- list files and list vector stores for cleanup;
- representative 429/5xx responses return `OpenAI.API.ErrorResponse` with the expected kind.

#### FileStore tests

Use `Req.Test` stubs and the `Secrets` context (not raw DB writes):

- first upload creates file + vector store, attaches file, polls vector-store-file until complete, and stores active JSON state;
- refresh creates a new file/store and does not switch active state until indexing succeeds;
- failed refresh leaves previous active state available;
- unchanged catalog hash skips all OpenAI API calls;
- empty collection clears/deletes active resources so old records are not searchable;
- partial failures best-effort clean up newly created resources;
- cleanup deletes only inactive ML-managed resources and skips unrelated OpenAI files/vector stores;
- `get_vector_store_id/0` returns `{:ok, id}` only for complete active state and `{:error, :not_uploaded}` otherwise.

#### Worker tests

- `perform/1` delegates to FileStore and returns `:ok` on success;
- structured OpenAI errors are routed through `Worker.ErrorHandler`;
- debounced enqueue creates one scheduled job and later enqueue replaces `scheduled_at` rather than first-writer-wins;
- a mutation can enqueue a follow-up job when another refresh job is already executing or no scheduled job exists.

#### Records/enrichment tests

- `create_record/1`, `update_record/2`, and `delete_record/1` enqueue `RefreshCollectionFile` via `assert_enqueued`;
- failed changes do not enqueue;
- catalog-affecting enrichment/direct update paths enqueue after success, especially genre population;
- bulk import or repeated creates coalesce into a single scheduled refresh with the latest scheduled time.

#### Collection/LiveView tests

- `stats_summary/0` returns stats string and correct count;
- `stats_summary/0` returns `{ "", 0 }` for empty collection;
- `file_search_catalog/0` returns deterministic catalog text and hash;
- `CollectionLive.Index` uses `@collection_stats`, not `@collection_summary`, and Chat receives the stats tuple.

#### CollectionChat/OpenAI request tests

- instructions include stats and count;
- instructions do **not** include per-record catalog lines, even with records present;
- active FileStore secret causes request tools to include `file_search` with the vector store ID;
- missing/incomplete FileStore secret omits `file_search` and keeps `web_search_preview`;
- `web_search_preview` remains present for all chat types;
- SSE fixtures including `response.file_search_call.*` events stream successfully via the existing `response.*` catch-all;
- existing record and artist chat request shapes remain unchanged.

---

### Phase 8: Verification

Run the normal checks required by the task DoD:

- `mix compile --warnings-as-errors`
- `mix test`
- `mix format --check-formatted`
- `mix credo`

Implementation-time manual verification:

1. Compare before/after collection chat instruction byte/token estimates.
2. Run one FileStore refresh against test stubs and inspect logs for successful upload/index/switch/cleanup ordering.
3. Confirm a simulated failed refresh leaves the previous vector store ID active.
4. Confirm empty collection does not leave the old catalog searchable.
5. If UI-visible code changes beyond the assign rename, use browser tooling for the collection page; otherwise no visual verification is required.

---

### Phase 9: Production and documentation

No new server environment variables are expected; the implementation uses the existing `OPENAI_KEY`. Document this explicitly. Confirm the OpenAI project/key has access to Files, Vector Stores, and Responses `file_search`.

Production rollout behavior:

- initial upload happens through the hourly cron after deploy;
- if the user wants immediate availability, ask before performing any production action, then trigger `RefreshCollectionFile` through existing admin tooling/Oban UI;
- rollback/fallback is safe because collection chat works stats-only when the active FileStore secret is missing or incomplete;
- cleanup worker removes stale ML-managed OpenAI files/vector stores, never unrelated resources.

Update documentation:

- `docs/architecture.md` — add `CollectionChat.FileStore`, OpenAI file/vector-store endpoints, `:open_ai` queue, refresh/cleanup workers, and updated collection chat data flow.
- `docs/production-infrastructure.md` — add OpenAI Files/Vector Stores usage, cost profile with current pricing checked at implementation time, no-new-env-var note, initial refresh behavior, cleanup/rollback notes, and operational cautions.
- Update any relevant tests/docs comments if function names change (`collection_summary/0`, `stats_summary/0`, `file_search_catalog/0`).
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
