---
name: external-api-integration
description: Use this skill when adding, modifying, extending, or debugging ANY external API integration (MusicBrainz, Last.fm, Discogs, Wikipedia, OpenAI, BraveSearch, Mailgun). Use PROACTIVELY when the user mentions "API", "integration", "HTTP client", "rate limit", "Req", "MusicBrainz", "Last.fm", "Discogs", "Wikipedia", "OpenAI", "Brave", "webhook", "external service", "third-party API", "error response", or asks about API patterns. Also use when adding new API calls to existing integrations or creating worker modules for API operations.
---

# External API Integration

Project-specific patterns for external API integrations. Every integration follows a
consistent three-module architecture with rate limiting, structured error handling,
and test stubbing.

## Checklist Before Adding or Modifying an API Integration

1. **Does an `ErrorResponse` module exist?** Every API MUST have a
   `<API>.API.ErrorResponse` module implementing `MusicLibrary.ErrorResponse` behaviour.

2. **Is rate limiting configured?** Every API uses `Req.RateLimiter` with a
   per-API interval. Check the architecture doc for existing intervals.

3. **Are test stubs in place?** All HTTP calls must be stubbed via `config/test.exs`
   using `Req.Test`. Use fixture modules for response data.

4. **Does the worker use `ErrorHandler`?** Workers that call APIs must route errors
   through `MusicLibrary.Worker.ErrorHandler.to_oban_result/1`.

## Three-Module Architecture

Every external API integration follows this pattern:

```
lib/music_library/<service>/
├── <service>.ex           # Facade: public API, delegates to API module
├── api.ex                 # API: Req HTTP client, rate-limited
├── api/
│   ├── config.ex          # Config: NimbleOptions schema, reads from app env
│   ├── error_response.ex  # ErrorResponse: implements MusicLibrary.ErrorResponse behaviour
│   └── fixtures.ex        # Fixtures: test response data (for API-specific fixtures)
```

### Facade Module (`<Service>.ex`)

The public interface. No HTTP logic here — delegates to the API module:

```elixir
defmodule MusicLibrary.LastFm do
  @spec get_recent_tracks(keyword()) :: {:ok, [LastFm.Track.t()]} | {:error, term()}
  def get_recent_tracks(opts \\ []) do
    LastFm.API.get_recent_tracks(opts)
  end
end
```

### API Module (`api.ex`)

Req-based HTTP client. Uses `Req.RateLimiter` via the request pipeline:

```elixir
defmodule MusicLibrary.LastFm.API do
  @spec get_recent_tracks(keyword()) :: {:ok, [LastFm.Track.t()]} | {:error, term()}
  def get_recent_tracks(opts) do
    config = LastFm.API.Config.new!(opts)

    Req.new(
      base_url: "https://ws.audioscrobbler.com/2.0",
      params: [api_key: config.api_key, format: "json"],
      plugins: [
        {Req.RateLimiter, id: :last_fm}
      ]
    )
    |> Req.get(url: "/", params: [method: "user.getRecentTracks", user: config.user])
    |> case do
      {:ok, %{status: 200, body: body}} -> {:ok, parse_tracks(body)}
      {:ok, %{status: status, body: body}} -> {:error, LastFm.API.ErrorResponse.new(status, body)}
      {:error, error} -> {:error, error}
    end
  end
end
```

Key patterns:
- **Config goes first** — build it from opts, validate with NimbleOptions
- **Rate limiter as Req plugin** — `{Req.RateLimiter, id: :service_name}`
- **Non-200 status codes** are wrapped in `ErrorResponse` structs, not raw maps
- **Req-level errors** (timeouts, DNS) are passed through as-is
- **Successful responses** are parsed into domain structs

### Config Module (`api/config.ex`)

NimbleOptions schema, reads from application env:

```elixir
defmodule MusicLibrary.LastFm.API.Config do
  @schema [
    api_key: [type: :string, required: true],
    shared_secret: [type: :string, required: false],
    user: [type: :string, required: false]
  ]

  def new!(opts) do
    env = Application.get_env(:music_library, :last_fm, [])

    opts
    |> Keyword.merge(env)
    |> NimbleOptions.validate!(@schema)
  end
end
```

## ErrorResponse Behaviour

Every API must have an `ErrorResponse` module implementing:

```elixir
defmodule MusicLibrary.ErrorResponse do
  @type t :: struct()
  @callback retryable?(t()) :: boolean()
  @callback retry_delay_seconds(t()) :: non_neg_integer() | nil
end
```

Example implementation:

```elixir
defmodule MusicLibrary.LastFm.API.ErrorResponse do
  defstruct [:status, :body, :kind]

  @behaviour MusicLibrary.ErrorResponse

  def new(status, body) do
    %__MODULE__{
      status: status,
      body: body,
      kind: MusicLibrary.HttpError.kind(status)  # baseline mapping
    }
  end

  @impl true
  def retryable?(%{kind: :rate_limit}), do: true    # 429
  def retryable?(%{kind: :server_error}), do: true   # 5xx
  def retryable?(_), do: false

  @impl true
  def retry_delay_seconds(%{status: 429, body: %{"error" => _, "message" => msg}}) do
    MusicLibrary.RetryDelay.parse(msg)  # parse Retry-After header
  end

  def retry_delay_seconds(_), do: nil
end
```

### HTTP Error Kind Mapping (`MusicLibrary.HttpError`)

Baseline mapping used by all APIs:

| HTTP status | Kind |
|-------------|------|
| 429 | `:rate_limit` |
| 5xx | `:server_error` |
| Timeout | `:timeout` |
| 401/403 | `:auth_error` |
| 404 | `:not_found` |
| 4xx | `:client_error` |
| Other | `:unknown` |

**Per-API overrides**: Some APIs have quirks that override the baseline:
- **MusicBrainz**: HTTP 503 is their rate-limit signal (not a server error)
- **OpenAI**: HTTP 429 with body `code: "insufficient_quota"` is `:auth_error` (permanent), not `:rate_limit`

Override in the ErrorResponse module by pattern-matching on status + body before
falling through to `MusicLibrary.HttpError.kind/1`.

## Rate Limiting

### Intervals (from architecture doc)

| API | Interval |
|-----|----------|
| MusicBrainz | 1000 ms |
| Last.fm | 500 ms |
| Discogs | 2000 ms |
| Wikipedia | 1000 ms |
| BraveSearch | 1000 ms |
| OpenAI | 250 ms |

### Req.RateLimiter

ETS-backed, per-API enforcement via Req request step. Configured per-request:

```elixir
Req.new(plugins: [{Req.RateLimiter, id: :music_brainz}])
```

The `:id` atom corresponds to the `Req.RateLimiter` ETS table entry. In tests,
use `Req.RateLimiter.Clock` behaviour with `SystemClock` implementation.

## Worker Error Handling

Workers that call APIs follow this flow:

```elixir
defmodule MusicLibrary.Worker.FetchArtistInfo do
  use Oban.Worker

  @impl true
  def perform(%{args: %{"musicbrainz_id" => mbid}}) do
    case Artists.fetch_info(mbid) do
      {:ok, _artist} ->
        :ok

      {:error, :no_english_wikipedia} ->
        # App-layer permanent failures — match first
        {:cancel, :no_english_wikipedia}

      {:error, reason} ->
        # Forward to ErrorHandler for structured HTTP error handling
        MusicLibrary.Worker.ErrorHandler.to_oban_result(reason)
    end
  end
end
```

`ErrorHandler.to_oban_result/1`:
- `%ErrorResponse{retryable?: true}` → `{:snooze, seconds}` (Oban snooze + retry)
- `%ErrorResponse{retryable?: false}` → `{:cancel, reason}` (permanent)
- Other errors → `{:error, reason}` (Oban default retry)

### Worker Return Values

| Return | Meaning | Oban Behaviour |
|--------|---------|----------------|
| `:ok` | Success | Job completed |
| `{:error, reason}` | Transient failure | Default retry with backoff |
| `{:snooze, seconds}` | Retryable with delay | Retry after `seconds` |
| `{:cancel, reason}` | Permanent failure | Job cancelled, never retried |

**Never use `{:discard, reason}`** — it's deprecated. Use `{:cancel, reason}`.

## Test Stubs (Req.Test)

All API HTTP calls are stubbed in `config/test.exs`:

```elixir
# config/test.exs
config :req, plug: {
  Req.Test,
  json_plug: &YourApp.JsonPlug.json/1
}
```

Each API's fixture module provides realistic response data. When adding a new API call:

1. **Add stub in `config/test.exs`** matching the request pattern
2. **Use fixture data** from the appropriate fixtures module
3. **Cover error cases**: rate limit (429), auth error (401/403), not found (404), server error (5xx)

```elixir
# Example: stubbing Last.fm with fixture
Req.Test.stub(LastFm.API, fn conn ->
  case conn.method do
    "GET" -> Req.Test.json(conn, LastFm.Fixtures.RecentTracks.get())
  end
end)
```

### Available API Fixture Modules

| Module                              | API                        |
| ----------------------------------- | -------------------------- |
| `MusicBrainz.Fixtures.Release`      | MusicBrainz release data   |
| `MusicBrainz.Fixtures.ReleaseGroup` | MusicBrainz release groups |
| `MusicBrainz.Fixtures.Artist`       | MusicBrainz artist data    |
| `BraveSearch.Fixtures`              | Brave Search responses     |
| `Discogs.Fixtures.Artist`           | Discogs artist profiles    |
| `LastFm.Fixtures.Artist`            | Last.fm artist info        |
| `LastFm.Fixtures.RecentTracks`      | Last.fm scrobble history   |
| `Wikipedia.Fixtures`                | Wikipedia extracts         |

## Adding a New API Integration

Step-by-step:

1. **Create directory** `lib/music_library/<service>/`
2. **Create Config** (`api/config.ex`) — NimbleOptions schema
3. **Create ErrorResponse** (`api/error_response.ex`) — implement behaviour, handle quirks
4. **Create API** (`api.ex`) — Req client with rate limiter plugin
5. **Create Facade** (`<service>.ex`) — public functions, delegates to API
6. **Register rate limiter** in `config/config.exs` with interval
7. **Add test stubs** in `config/test.exs`
8. **Create fixture module** in `test/support/fixtures/`
9. **Update architecture doc** — add to External API Integrations table
10. **Add worker** (if needed) — thin wrapper with ErrorHandler
