---
name: oban-worker
description: Use this skill when creating, modifying, debugging, or reviewing ANY Oban worker. Use PROACTIVELY when the user mentions "worker", "Oban", "background job", "job", "cron", "queue", "perform", "enqueue", "schedule", "async", "snooze", "cancel", "discard", or asks about running work in the background. Also use when adding Oban plugins, changing queue configuration, or writing worker tests.
---

# Oban Worker Development

Project-specific patterns for Oban background job workers. Every worker follows
consistent conventions for structure, error handling, queue assignment, and testing.

## Checklist Before Creating or Modifying a Worker

1. **Does the worker delegate to a context module?** `perform/1` must be a thin wrapper.
   No business logic inline.

2. **Is the queue correct?** Rate-limited APIs get dedicated queues with per-service
   concurrency limits. DB-intensive operations go to `heavy_writes`. General tasks go to
   `default`.

3. **Does error handling use `ErrorHandler`?** Workers calling APIs route HTTP errors
   through `MusicLibrary.Worker.ErrorHandler.to_oban_result/1`.

4. **Is the worker registered under the correct Oban instance?** Production uses
   `MusicLibrary.BackgroundRepo` as the Oban instance.

## Worker Structure

```elixir
defmodule MusicLibrary.Worker.FetchArtistInfo do
  use Oban.Worker,
    queue: :default,           # Pick the right queue (see below)
    max_attempts: 3,            # Oban default, override if needed
    unique: [period: 60]        # Optional: prevent duplicate jobs

  @impl true
  def perform(%Oban.Job{args: %{"musicbrainz_id" => mbid}}) do
    # Delegate to context — no business logic here
    case Artists.fetch_info(mbid) do
      {:ok, _artist} ->
        :ok

      # App-layer permanent failures matched FIRST
      {:error, :no_english_wikipedia} ->
        {:cancel, :no_english_wikipedia}

      {:error, :cover_not_available} ->
        {:cancel, :cover_not_available}

      # Everything else routed through ErrorHandler
      {:error, reason} ->
        MusicLibrary.Worker.ErrorHandler.to_oban_result(reason)
    end
  end
end
```

## Queues

| Queue | Concurrency | Use For |
|-------|-------------|---------|
| `default` | 10 | General async tasks, non-API operations |
| `heavy_writes` | 1 | DB-intensive or serialized operations |
| `openai` | 3 | OpenAI API calls |
| `music_brainz` | 3 | MusicBrainz API calls |
| `discogs` | 1 | Discogs API calls |
| `wikipedia` | 3 | Wikipedia API calls |
| `last_fm` | 3 | Last.fm API calls |

**Rule**: Any worker that calls an external API goes on that API's dedicated queue.
The dedicated concurrency combined with `Req.RateLimiter` ensures the API rate limit
is never exceeded.

## Return Values

| Return | Meaning | Oban Behaviour |
|--------|---------|----------------|
| `:ok` | Success | Job marked complete |
| `{:ok, result}` | Success with result | Job marked complete |
| `{:error, reason}` | Transient failure | Oban retries with backoff |
| `{:snooze, seconds}` | Retryable with delay | Oban retries after `seconds` |
| `{:cancel, reason}` | Permanent failure | Job cancelled, never retried |

**CRITICAL**: Never use `{:discard, reason}` — it's deprecated since Oban 2.14.
Always use `{:cancel, reason}`.

## Error Handling Flow

```
perform/1
  ├── App-layer permanent failures (match FIRST)
  │   ├── :no_english_wikipedia → {:cancel, :no_english_wikipedia}
  │   ├── :cover_not_available → {:cancel, :cover_not_available}
  │   └── ...other domain-specific permanent failures
  │
  └── Everything else → MusicLibrary.Worker.ErrorHandler.to_oban_result(reason)
      ├── %ErrorResponse{retryable?: true}  → {:snooze, seconds}
      ├── %ErrorResponse{retryable?: false} → {:cancel, reason}
      └── Other errors                      → {:error, reason}
```

The order matters: **app-layer atoms first**, then fall through to `ErrorHandler`.
This ensures domain-specific permanent failures (e.g., no Wikipedia article exists)
are handled correctly before generic HTTP error classification kicks in.

## Cron Workers

Scheduled via `Oban.Plugins.Cron` in production config:

```elixir
# config/prod.exs
config :music_library, Oban,
  plugins: [
    {Oban.Plugins.Cron,
     crontab: [
       {"@daily", MusicLibrary.Worker.SendRecordsOnThisDayEmail},
       {"*/5 * * * *", MusicLibrary.Worker.RefreshScrobbles}
     ]}
  ]
```

Cron workers follow the same thin-wrapper pattern. The cron expression is the only
difference from on-demand workers.

### All Cron Workers

| Schedule | Worker | Queue |
|----------|--------|-------|
| Every 12h | `ApplyScrobbleRules` | heavy_writes |
| Every 12h | `PruneAssetCache` | default |
| Daily 2 AM | `PruneAssets` | default |
| Daily 3:03 AM | `RepoVacuum` | heavy_writes |
| Daily 4 AM | `RepoOptimize` | heavy_writes |
| Monthly 1st, 6 AM | `RecordRefreshAllMusicBrainzData` | music_brainz |
| Monthly 1st, 7 AM | `RecordGenerateAllEmbeddings` | heavy_writes |
| Monthly 1st, 8 AM | `ArtistRefreshAllMusicBrainzData` | music_brainz |
| Monthly 1st, 9 AM | `ArtistRefreshAllDiscogsData` | discogs |
| Monthly 1st, 10 AM | `ArtistRefreshAllWikipediaData` | wikipedia |
| Daily 7 AM | `SendRecordsOnThisDayEmail` | default |
| Every 5 min | `RefreshScrobbles` | last_fm |

## Oban Plugins (Production)

| Plugin | Config | Purpose |
|--------|--------|---------|
| `Pruner` | `max_age: 604800` (7 days) | Clean up completed jobs |
| `Reindexer` | `schedule: "@weekly"` | Reindex for query performance |
| `Cron` | timezone: `"Europe/London"` | Schedule recurring jobs |

## Batch Workers (Self-Chaining)

Some workers process data in batches, enqueuing their next batch on completion:

```elixir
def perform(%{args: %{"page" => page}}) do
  case process_page(page) do
    {:ok, []} ->
      :ok  # No more data, done

    {:ok, _results} ->
      # Enqueue next page
      %{page: page + 1}
      |> __MODULE__.new()
      |> Oban.insert()

      :ok
  end
end
```

The `Records.Batch` and `Artists.Batch` modules provide shared batch infrastructure
(`stream + transaction + error accumulation`). Bulk workers should use these rather
than implementing their own batching logic.

## Testing Workers

### Manual mode

Oban runs in manual testing mode — jobs don't auto-execute. Use `perform_job/2`:

```elixir
import Oban.Testing, only: [perform_job: 2]

test "fetches artist info" do
  job = MyWorker.new(%{musicbrainz_id: "abc-123"})
  assert :ok = perform_job(MyWorker, job.args)
end
```

### Assert enqueued downstream jobs

Workers that enqueue other jobs MUST verify with `assert_enqueued`:

```elixir
assert_enqueued(worker: FetchArtistImage, args: %{musicbrainz_id: "abc-123"})
```

`perform_job` returning `{:ok, []}` is NOT sufficient — verify the expected downstream
workers were enqueued with correct args.

### Testing all return states

```elixir
# Success
assert :ok = perform_job(MyWorker, %{id: valid_id})

# Transient (Oban retries)
assert {:error, :rate_limit} = perform_job(MyWorker, %{id: rate_limited_id})

# Permanent (job cancelled)
assert {:cancel, :no_english_wikipedia} = perform_job(MyWorker, %{id: missing_id})
```

## Non-Fatal Enrichment

Context functions that enrich records (colors, embeddings) use a private
`best_effort_*` helper pattern — log a warning and return unchanged data rather
than surfacing `{:error, reason}`. Workers calling these functions don't need
error handling for enrichment failures.
