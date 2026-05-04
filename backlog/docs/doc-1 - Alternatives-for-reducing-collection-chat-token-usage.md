---
id: doc-1
title: Alternatives for reducing collection chat token usage
type: other
created_date: "2026-05-02 16:12"
updated_date: "2026-05-04 06:55"
---

# ML-156 Research: Alternatives for reducing collection chat token usage

Research document for [ML-156 - Explore alternatives to reduce token usage when providing collection context to LLM for collection chat](backlog://task/ML-156).

---

## Current state

**Token flow per new collection chat:**

1. `Collection.collection_summary/0` runs on mount via `start_async`
2. Loads ALL records: `from(r in Record, where: not is_nil(r.purchased_at), order_by: [order_alphabetically()], select: ^essential_fields())`
3. Groups by `musicbrainz_id`, formats each group as `"Artist - Title (year, formats) [genre1, genre2]"`
4. Builds stats header: `"# Stats: N releases, M artists\nGenres: ...\nFormats: ...\nEras: ..."`
5. Returns `{stats + "\n\n" + catalog, group_count}`
6. Stored in `@collection_summary` assign on the LiveView
7. Passed to Chat component as `chat_context={@collection_summary}`
8. When user sends first message, `do_send_message` calls `chat_module.stream_response(messages, chat_context, callback)`
9. `CollectionChat.stream_response/3` calls `build_instructions(summary, record_count)`
10. `build_instructions/2` calls `Prompt.build/2` which wraps the summary in identity + approach templates
11. Full instructions string is sent as the `instructions` field in the OpenAI Responses API request

**Token estimate per catalog entry:** ~15-20 tokens (e.g., "Radiohead - OK Computer (1997, cd/vinyl) [alternative rock, art rock]\n")
**For 500 releases:** ~9,000 input tokens for catalog alone + ~100 tokens for stats + ~500 tokens for prompt template = ~9,600 tokens

**Key files:**

- `lib/music_library/collection.ex:203-235` — `collection_summary/0` (loads and formats all records)
- `lib/music_library/chats/collection_chat.ex:18-31` — `build_instructions/2` (embeds summary in prompt)
- `lib/music_library/chats/prompt.ex` — `Prompt.build/2` (wraps in identity + approach)
- `lib/open_ai/api.ex:54-73` — `chat_stream/6` (sends to Responses API with `tools: [%{type: "web_search_preview"}]`)
- `lib/open_ai/api.ex:158-178` — `decode_responses_event/2` (SSE parser, currently only handles `response.output_text.delta`, `response.failed`, generic `response.*`)
- `lib/music_library_web/components/chat.ex:196-234` — `do_send_message/2` (dispatches to `chat_module.stream_response`)
- `lib/music_library_web/live/collection_live/index.ex:226-233,246-254,304-305` — Chat component mount and summary async loading

### Streaming architecture constraints

The Chat component dispatches streaming to a `Task.Supervisor` child:

```elixir
Task.Supervisor.start_child(MusicLibrary.TaskSupervisor, fn ->
  case chat_module.stream_response(stream_messages, chat_context, fn chunk ->
    LiveView.send_update(parent_pid, __MODULE__, id: component_id, chunk: chunk)
  end) do
    :ok -> LiveView.send_update(parent_pid, __MODULE__, id: component_id, done: true)
    {:error, reason} -> ...send error update...
  end
end)
```

The callback sends `[chunk: chunk]` updates; `update/2` in the Chat component accumulates text via `MDEx.Document.put_markdown`. The response is rendered as streaming markdown.

---

## Alternatives

### Alternative A: Stats-only instructions (no catalog)

**Description:** Remove the catalog lines from instructions. Keep only the aggregated stats (release count, artist count, top genres, formats, eras).

**Token savings:** ~9,000 → ~100 input tokens (~99% reduction)

**Pros:**

- Simplest possible change; < 10 lines of code
- No architectural changes needed
- No streaming infrastructure changes
- The LLM can still answer statistical questions ("what's my most common genre?", "how many jazz records do I have?")

**Cons:**

- LLM loses ability to answer specific questions ("do I have Kid A?", "which Radiohead albums do I own?", "show me my 90s electronic albums")
- User experience degrades for record-specific queries
- The LLM will hallucinate or say "I don't have access to your specific collection" frequently

**Impact on code:**

1. `CollectionChat.build_instructions/2` — remove `#{collection_summary}` interpolation, keep only stats
2. `Collection.collection_summary/0` — could be simplified to return only stats (or keep as-is, the function is also tested independently)

---

### Alternative B: Function calling (tool-based search)

**Description:** Provide the LLM with a `search_collection` function tool. The LLM calls this tool when it needs to look up specific records in the user's collection. The instructions only include aggregated stats.

**Token savings:** ~9,000 → ~100 input tokens base + tool call overhead + tool results (~200-500 tokens when actually searching)

**How it works:**

1. Add a tool definition to the Responses API request:

```json
{
  "type": "function",
  "name": "search_collection",
  "description": "Search the user's music collection by artist name, album title, genre, format, or any combination",
  "parameters": {
    "type": "object",
    "properties": {
      "query": { "type": "string", "description": "Search query" }
    },
    "required": ["query"]
  }
}
```

2. The SSE streaming flow changes: instead of simple text-delta → done, we need to handle:
   - `response.function_call_arguments.delta` / `response.function_call_arguments.done`
   - Build the function call from accumulated deltas
   - Execute `Collection.search_records(query)` locally
   - Submit the function result back to the Responses API (second request)
   - Continue streaming the text response

3. The Chat component's streaming architecture needs to handle this multi-turn flow.

**Pros:**

- Maximal token efficiency — only pay for what's actually needed
- LLM can answer arbitrary specific questions with real data
- Scales to any collection size
- The same tool pattern could be reused for artist chat, record chat, etc.
- Leverages the existing `tools` infrastructure in the Responses API request

**Cons:**

- **Significantly more complex** — requires:
  - Changes to `OpenAI.API.chat_stream/6` to support function calls in streaming mode
  - Changes to `decode_responses_event/2` to handle function call SSE events
  - A function call execution loop (model calls function → execute → submit result → model responds)
  - Changes to the Chat component's `do_send_message/2` to orchestrate multi-turn tool use
  - The streaming Task process becomes stateful (needs to handle the submit-then-continue loop)
- Tool results still consume tokens (but only the matching records, not the entire catalog)
- User may experience a brief pause while the tool executes (mitigated by streaming the tool call status)
- More error states to handle (function execution failures, parse errors)

**Implementation scope:**

1. **Tool definition module** — New module ~30 lines defining the OpenAI function tool schema
2. **Function executor** — New module or function in `CollectionChat` that executes the tool call (~20 lines)
3. **Streaming changes in `OpenAI.API`** — New `chat_stream_with_tools/7` or modify `chat_stream/6` to accept tools and handle function call events (~80 lines)
4. **SSE event handling** — Add cases to `decode_responses_event/2` for function call events (~30 lines)
5. **Chat component orchestration** — Modify `do_send_message/2` or the Task function to handle tool call loops (~50 lines)
6. **`CollectionChat.build_instructions/2`** — Remove catalog, keep stats, add tool usage guidance (~10 lines)

**Estimated lines of change:** ~200-300 lines across 6-8 files

---

### Alternative C: Cached LLM-generated summary

**Description:** Generate a concise, human-readable summary of the collection using an LLM call (e.g., "Your collection spans from 1967 to 2024 with a focus on progressive rock, featuring 3 albums by Radiohead, 2 by Pink Floyd..."). Store this summary in a `Chat` record or asset, and regenerate it when the collection changes (record added/removed/edited).

**Token savings:** ~9,000 → ~400 tokens (summary text + stats)

**Pros:**

- Good middle ground — compact but informative
- The LLM has a narrative understanding of the collection
- No streaming architecture changes needed
- Single one-time cost to generate (amortized across many chats)

**Cons:**

- Still doesn't give the LLM ability to answer specific queries ("do I have Kid A?")
- Summary can go stale if not regenerated on collection changes
- Requires an initial LLM call to generate the summary (token cost + latency)
- When to regenerate is tricky — every record add/edit/delete?
- The summary is only as good as the LLM's compression; important details may be lost
- Adds a new background job / async concern

**Implementation scope:**

1. Store the cached summary (new DB field on a canonical collection `Chat` record, or a new schema)
2. A function/worker to generate the LLM summary (calls OpenAI, stores result)
3. Invalidation triggers (PubSub on record add/edit/delete, regenerate async)
4. Changes to `CollectionChat.build_instructions/2` to use the cached summary
5. Fallback to stats-only if cache is stale/missing

---

### Alternative D: Hybrid — stats in instructions + tool for catalog search

**Description:** Combine Alternative A (stats always included) with Alternative B (function calling for specific queries). The instructions include aggregated stats and guidance to use the `search_collection` tool when the user asks about specific records.

**Token savings:** ~9,000 → ~100 tokens base + tool results (0-500 tokens per use)

**Pros:**

- Best of both worlds: statistical awareness always available, specific lookup on demand
- Token-efficient — base cost is minimal
- LLM knows to reach for the tool when appropriate

**Cons:**

- Same implementation complexity as Alternative B for the tool infrastructure
- Slightly more prompt engineering to ensure the model uses the tool appropriately

**Implementation scope:** Same as Alternative B, plus refined prompt instructions.

---

### Alternative E: OpenAI `file_search` tool (recommended)

Upload the collection catalog as a file to OpenAI, create a vector store, and use the Responses API's built-in `file_search` tool. OpenAI automatically performs semantic search over the file and includes relevant results inline.

**Token savings:** ~9,000 → ~100 tokens base + retrieval overhead (~200-500 when model searches)

**How it works:**

1. Format collection catalog as text (same as current `collection_summary/0` output)
2. Upload to OpenAI: `POST /v1/files` with `purpose: "assistants"` → `file_id`
3. Create vector store: `POST /v1/vector_stores` → `vector_store_id`
4. Attach file: `POST /v1/vector_stores/{id}/files` → OpenAI indexes it
5. In `chat_stream`, add `%{type: "file_search", vector_store_ids: [store_id]}` to tools
6. Model searches file when needed — results appear inline, same as web_search_preview today

**Critical difference from Alt B:** No SSE event handling changes, no orchestration loop, no custom tool execution. `file_search` works exactly like `web_search_preview` (already in use) — OpenAI handles retrieval automatically.

**Pros:**

- ~150 lines vs ~250 for Alt B
- No changes to `decode_responses_event/2` or Chat streaming loop
- Semantic search (finds "upbeat 80s rock" not just keywords)
- Files only uploaded on collection change (amortized cost)
- Reusable for artist bios, notes, etc.

**Cons:**

- File can go stale if not updated on collection change
- 2-3 new API endpoints needed (Files API, Vector Stores API)
- Vector store indexing is async (may need brief poll)
- First chat after deploy has upload+index latency
- File storage cost at OpenAI (negligible for text)
- Search quality depends on OpenAI's embedding model, not directly controllable

---

## Comparison

| Criterion                 | A (stats-only) | B (custom func) | C (cached) | E (file_search) |
| ------------------------- | -------------- | --------------- | ---------- | --------------- |
| Implementation complexity | ★☆☆☆☆          | ★★★★☆           | ★★★☆☆      | ★★☆☆☆           |
| Response quality          | ★★☆☆☆          | ★★★★★           | ★★★☆☆      | ★★★★★           |
| Token efficiency          | ★★★★★          | ★★★★★           | ★★★★☆      | ★★★★★           |
| Infrastructure risk       | ★★★★★          | ★★★☆☆           | ★★★★☆      | ★★★★☆           |
| Reusability               | ★☆☆☆☆          | ★★★★☆           | ★★☆☆☆      | ★★★☆☆           |

---

## Why Alternative E over B

Alternative E (`file_search`) was chosen over Alternative B (custom function calling) for these reasons:

1. **Same response quality with half the code** (~150 lines vs ~250 lines). Both approaches let the LLM answer arbitrary specific questions with real collection data.

2. **No streaming infrastructure changes.** Alternative B requires modifying `decode_responses_event/2`, the SSE event loop, and `do_send_message/2` to handle function call orchestration. Alternative E simply adds a `file_search` tool entry alongside the existing `web_search_preview` — no new SSE event types to parse, no orchestration loop, no stateful streaming.

3. **Lower risk.** The core streaming code path is untouched. The new code is additive (new API endpoints, new `FileStore` module) rather than modifying the shared streaming infrastructure that serves all three chat types (record, artist, collection).

4. **Better search quality.** OpenAI's semantic search is likely superior to FTS5 for natural language queries like "upbeat 80s rock with synths".

5. **Alternative B would be the right choice if** the application needed parameterized queries (artist+format+year range), real-time data that changes mid-chat, or complex database filtering. For a static-ish catalog that changes infrequently, `file_search` is the pragmatic choice.
