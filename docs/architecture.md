# Architecture Summary

> **Maintenance rule**: Update this file whenever you add, remove, or restructure modules,
> schemas, contexts, workers, routes, or external integrations. Keep descriptions factual
> and concise. This file exists to accelerate future iteration — treat it as a living map.

## Overview

Phoenix LiveView application for managing a personal music collection and wishlist.
Uses SQLite (via `ecto_sqlite3`) with three databases: one for the app, one for background
jobs (Oban), and one for telemetry metrics. All schemas use `binary_id` primary keys.

Key capabilities:

- Browse/search collected and wishlisted records
- Import metadata from MusicBrainz, enrich with Discogs/Wikipedia/Last.fm
- Scrobble tracks to Last.fm, import listening history
- Similarity search via OpenAI embeddings + sqlite-vec
- AI-powered record chat via OpenAI streaming with web search
- Barcode scanning for quick imports
- Encrypted secret storage (Cloak)
- Presto companion display (MicroPython, 4" IPS LCD, "Records on this day")

**Elixir 1.20.1, Phoenix ~> 1.8, LiveView ~> 1.1, SQLite3**

---

## Supervision Tree

```
MusicLibrary.Application (one_for_one)
├── ErrorTracker.ErrorNotifier    # Telemetry-driven error email notifications
├── MusicLibrary.Vault           # Cloak encryption vault
├── MusicLibrary.Repo            # Main SQLite repo
├── MusicLibrary.BackgroundRepo  # Oban SQLite repo (separate DB)
├── MusicLibrary.TelemetryRepo   # Telemetry metrics SQLite repo
├── MusicLibraryWeb.Telemetry    # Telemetry supervisor
│   ├── Telemetry.Storage        # Buffered metrics storage (in-memory, 5s flush to SQLite, force-flush on read)
│   └── :telemetry_poller        # 30s periodic measurements
├── Phoenix.PubSub (:music_library)
├── Oban                         # Background job engine
├── Ecto.Migrator                # Migrations (skipped in release; run by Coolify post-deploy)
├── Task.Supervisor (MusicLibrary.TaskSupervisor)
└── MusicLibraryWeb.Endpoint
```

Logster v2 (production-only) is attached as a telemetry handler via `application.ex`
when `single_line_logging` is `true` — not a supervised process.

---

## Database & Repos

| Repo                          | DB file (dev)                          | Purpose                                                |
| ----------------------------- | -------------------------------------- | ------------------------------------------------------ |
| `MusicLibrary.Repo`           | `data/music_library_dev.db`            | All application data                                   |
| `MusicLibrary.BackgroundRepo` | `data/music_library_background_dev.db` | Oban job queue                                         |
| `MusicLibrary.TelemetryRepo`  | `data/music_library_telemetry_dev.db`  | Telemetry metrics history (persistent across restarts) |

SQLite extensions loaded at runtime: `unicode`, `vec0` (vector search).

FTS5 virtual table `records_search_index` auto-synced via database triggers — do not
write to it directly; insert/update the `records` table instead.

---

## Schemas

| Schema                                     | Table                    | PK               | Key Fields                                                                                                                                 |
| ------------------------------------------ | ------------------------ | ---------------- | ------------------------------------------------------------------------------------------------------------------------------------------ |
| `Records.Record`                           | `records`                | `id` (binary_id) | title, type, format, cover_url, cover_hash, musicbrainz_id, genres[], release_date, purchased_at, dominant_colors[], embeds_many :artists  |
| `Records.RecordEmbedding`                  | `record_embeddings`      | `id`             | embedding (Float32 vector), text_representation, belongs_to :record                                                                        |
| `Records.SearchIndex`                      | `records_search_index`   | `id`             | FTS5 mirror of records (virtual, trigger-synced)                                                                                           |
| `Records.RecordRelease`                    | `record_releases`        | none             | record_id, release_id, cover_hash, purchased_at — read-only, no PK                                                                         |
| `Records.ArtistRecord`                     | `artist_records`         | composite        | musicbrainz_id, record_id — DB view joining artists to records                                                                             |
| `Artists.Artist`                           | —                        | —                | Embedded schema (name, sort_name, musicbrainz_id, joinphrase)                                                                              |
| `Artists.ArtistInfo`                       | `artist_infos`           | `id`             | musicbrainz_data, discogs_data, wikipedia_data, lastfm_data, image_data_hash                                                               |
| `Assets.Asset`                             | `assets`                 | `hash` (SHA256)  | content (binary), format, properties (map)                                                                                                 |
| `Notes.Note`                               | `notes`                  | `id`             | entity (:record/:artist), content, musicbrainz_id; survives record deletion (no FK, keyed by musicbrainz_id)                               |
| `RecordSets.RecordSet`                     | `record_sets`            | `id`             | name, description, has_many :items                                                                                                         |
| `RecordSets.RecordSetItem`                 | `record_set_items`       | `id`             | position, belongs_to :record_set, belongs_to :record                                                                                       |
| `ScrobbleRules.ScrobbleRule`               | `scrobble_rules`         | `id` (integer)   | type (:album/:artist), match_value, target_musicbrainz_id, enabled                                                                         |
| `OnlineStoreTemplates.OnlineStoreTemplate` | `online_store_templates` | `id`             | name, url_template, enabled                                                                                                                |
| `Secrets.Secret`                           | `secrets`                | `name` (string)  | value (encrypted binary)                                                                                                                   |
| `Chats.Chat`                               | `chats`                  | `id` (binary_id) | entity (:record/:artist/:collection), musicbrainz_id, topic, has_many :messages; survives record deletion (no FK, keyed by musicbrainz_id) |
| `Chats.Message`                            | `chat_messages`          | `id` (binary_id) | role, content, position, belongs_to :chat                                                                                                  |

Last.fm schemas (separate, not Ecto-persisted to main DB):

- `LastFm.Track` — scrobbled tracks from Last.fm API responses
- `LastFm.Album`, `LastFm.Artist` — parsed API responses

---

## Contexts (lib/music_library/)

| Context                | Schemas                                                               | Responsibility                                                                                                                                                                                                                                                                                                                                                          |
| ---------------------- | --------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Records`              | Record, RecordEmbedding, SearchIndex                                  | CRUD, search, import from MusicBrainz, cover/genre/color management, PubSub notifications                                                                                                                                                                                                                                                                               |
| `Collection`           | Record (via SearchIndex)                                              | Querying collected records (purchased_at != nil), stats, collected artist IDs, collection summary for AI chat. Sub-module `Collection.Enrichment` batch-hydrates API results with scrobble stats, artist country, and selected release info.                                                                                                                            |
| `Wishlist`             | Record (via SearchIndex)                                              | Querying wishlisted records (purchased_at is nil)                                                                                                                                                                                                                                                                                                                       |
| `Artists`              | ArtistInfo, ArtistRecord                                              | Artist metadata from MusicBrainz/Discogs/Wikipedia/Last.fm, images, search                                                                                                                                                                                                                                                                                              |
| `Assets`               | Asset                                                                 | Binary asset storage (covers, artist images), cache tracking, pruning unreferenced assets                                                                                                                                                                                                                                                                               |
| `Notes`                | Note                                                                  | Free-text notes for records and artists. Rows survive record deletion — keyed by `musicbrainz_id` (no FK to `records`), they attach to the musical entity.                                                                                                                                                                                                              |
| `Chats`                | Chat, Message, StreamProvider, RecordChat, ArtistChat, CollectionChat | Persistent AI chat conversations for records, artists, and the collection, streaming AI chat behaviour and entity-specific implementations. Chats survive record deletion — keyed by `musicbrainz_id` (no FK to `records`), they attach to the musical entity.                                                                                                          |
| `RecordSets`           | RecordSet, RecordSetItem                                              | User-curated record groupings with ordering                                                                                                                                                                                                                                                                                                                             |
| `ScrobbleRules`        | ScrobbleRule                                                          | Rules to remap Last.fm scrobble data to correct MusicBrainz IDs; searchable by match_value/target/description, orderable by alphabetical or inserted_at                                                                                                                                                                                                                 |
| `ScrobbleActivity`     | —                                                                     | Scrobbling releases/media/tracks to Last.fm                                                                                                                                                                                                                                                                                                                             |
| `ListeningStats`       | (LastFm.Track, RecordRelease, ArtistRecord, ArtistInfo)               | Scrobble persistence, refresh scheduling, listening analytics, track CRUD, search, listing: scrobble counts, artist play counts (from DB), recent activity, top albums/artists by period                                                                                                                                                                                |
| `OnlineStoreTemplates` | OnlineStoreTemplate                                                   | URL templates for buying records online; searchable by name/description                                                                                                                                                                                                                                                                                                 |
| `Errors`               | ErrorTracker.Error, ErrorTracker.Occurrence                           | Queries and mutations for production error data tracked by ErrorTracker; filtered listing with pagination, single error with preloaded occurrences and computed counts, plus `mute_error/1`, `unmute_error/1`, `resolve_error/1`, `unresolve_error/1` for mutating error state. Muting an error suppresses future email notifications via `ErrorTracker.ErrorNotifier`. |
| `Search`               | (cross-context)                                                       | Universal search dispatcher across collection, wishlist, artists, record sets (delegates to domain contexts)                                                                                                                                                                                                                                                            |
| `Secrets`              | Secret                                                                | Encrypted key-value storage (CRUD + delete)                                                                                                                                                                                                                                                                                                                             |
| `BarcodeScan`          | (Result struct)                                                       | Barcode → MusicBrainz lookup workflow, async batch import for multiple new records                                                                                                                                                                                                                                                                                      |
| `Maintenance`          | (Oban.Job, LastFm.Track)                                              | Background job monitoring, database vacuum/optimize, scrobble data quality diagnostics                                                                                                                                                                                                                                                                                  |

---

## Business Logic Modules

| Module                                    | Purpose                                                                                                                                                                                                                                        |
| ----------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Records.SearchParser`                    | Parses search syntax: `artist:X`, `album:X`, `genre:"Y"`, `format:cd`, `type:album`, `purchase_year:2024`, `release_year:2024`, free text                                                                                                      |
| `ListeningStats.SearchParser`             | Parses scrobbled tracks search syntax: `record:X`, `album_mbid:X`, `artist_mbid:X`, `artist:X`, `album:X`, `track:X`, free text                                                                                                                |
| `Records.Similarity`                      | Embedding generation and async enqueue (OpenAI, enriched with Last.fm tags, skips API call when text representation unchanged), artist-cascade regeneration when upstream metadata changes, cosine-distance search (sqlite-vec)                |
| `Records.TracklistPdf`                    | Generates 120mm×120mm PDF tracklist from record + release data (Typst)                                                                                                                                                                         |
| `Batch`                                   | Generic batch runner: stream + transaction + error accumulation                                                                                                                                                                                |
| `Records.Batch`                           | Batch operations: refresh all MusicBrainz data, generate all embeddings (uses `Batch`)                                                                                                                                                         |
| `Artists.Batch`                           | Batch refresh: MusicBrainz, Discogs, Wikipedia, Last.fm for all artists (uses `Batch`)                                                                                                                                                         |
| `Collection.Enrichment`                   | Batch-hydrates collection API results with scrobble stats (from `scrobbled_tracks`), artist country (from `artist_infos`), and selected release details (from `records.musicbrainz_data`). Uses 3 fixed-count queries regardless of page size. |
| `Req.RateLimiter`                         | ETS-backed Req request step enforcing per-API minimum intervals between requests                                                                                                                                                               |
| `Req.RateLimiter.Clock`                   | Behaviour for time operations (allows test clock injection)                                                                                                                                                                                    |
| `Req.RateLimiter.SystemClock`             | Real clock implementation using System.monotonic_time                                                                                                                                                                                          |
| `Assets.Cache`                            | ETS-based asset cache with TTL (7-day TTL, TTL-only invalidation since assets are content-addressable and immutable)                                                                                                                           |
| `Assets.Image` / `Assets.Transform`       | Image processing via Vix (libvips)                                                                                                                                                                                                             |
| `Colors.Extractor`                        | Behaviour for dominant color extraction (configurable, allows test stubbing)                                                                                                                                                                   |
| `Colors.KMeansExtractor`                  | Color extraction via K-Means clustering (dominant_colors library), implements `Colors.Extractor`                                                                                                                                               |
| `Chats.StreamProvider`                    | Behaviour for streaming AI chat (`stream_response/3` callback)                                                                                                                                                                                 |
| `Chats.RecordChat`                        | Chat implementation for records (OpenAI streaming, web search enabled)                                                                                                                                                                         |
| `Chats.ArtistChat`                        | Chat implementation for artists (OpenAI streaming, uses Wikipedia/artist context)                                                                                                                                                              |
| `Chats.CollectionChat`                    | Chat implementation for the collection (OpenAI streaming via gpt-5.1, uses collection summary as context)                                                                                                                                      |
| `Chats.Prompt`                            | Builds complete chat prompts by interpolating identity, content, and approach guidelines                                                                                                                                                       |
| `Country`                                 | Country code (alpha-2, alpha-3, subdivision, IETF) to flag emoji conversion                                                                                                                                                                    |
| `ErrorTracker.ErrorNotifier`              | GenServer: attaches to ErrorTracker telemetry, skips muted errors, throttles repeated errors, dispatches email notifications                                                                                                                   |
| `ErrorTracker.ErrorNotifier.Email`        | Builds and sends Swoosh error notification emails with stack trace formatting                                                                                                                                                                  |
| `ErrorIgnorer`                            | ErrorTracker.Ignorer implementation: filters non-actionable errors (e.g., NoRouteError from bot scanners)                                                                                                                                      |
| `MusicLibrary.ErrorResponse`              | Behaviour for structured API error responses (`retryable?/1`, `retry_delay_seconds/1`) — per-API `ErrorResponse` modules implement this                                                                                                        |
| `MusicLibrary.HttpError`                  | Default HTTP status → kind mapping (`:rate_limit`, `:server_error`, `:timeout`, `:auth_error`, `:not_found`, `:client_error`, `:unknown`) used as baseline by per-API `ErrorResponse` modules                                                  |
| `MusicLibrary.RetryDelay`                 | Parses and clamps provider retry/reset headers into Oban snooze delays for structured API errors                                                                                                                                               |
| `MusicLibrary.Worker.ErrorHandler`        | Translates per-API `ErrorResponse` structs into Oban tuples — `{:snooze, seconds}` for retryable, `{:cancel, reason}` for permanent                                                                                                            |
| `MusicLibraryWeb.RecordsOnThisDayEmail`   | Builds and sends daily "records on this day" email with cover images, anniversary styling                                                                                                                                                      |
| `MusicLibrary.Mailer`                     | Swoosh mailer (Mailgun in prod, local adapter in dev)                                                                                                                                                                                          |
| `FormatNumber`                            | Number formatting utility                                                                                                                                                                                                                      |
| `QueryReporter`                           | Dev-only Ecto telemetry reporter: captures executed SQL to a log file with interpolated params, source locations, and timing. Activated at runtime via `start/1` / `stop/0`                                                                    |
| `MusicLibrary.Logger.SingleLineFormatter` | Production-only Logger.Formatter safety net: replaces embedded newlines (`\n`) with escaped `\\n` in all log messages, ensuring every physical log line is exactly one log event                                                               |

---

## External API Integrations

| Module                            | API                  | Rate limit | Purpose                                                                                             |
| --------------------------------- | -------------------- | ---------- | --------------------------------------------------------------------------------------------------- |
| `MusicBrainz` / `MusicBrainz.API` | musicbrainz.org      | 1000 ms    | Release/artist metadata, search                                                                     |
| `LastFm` / `LastFm.API`           | last.fm              | 500 ms     | Scrobbling, listening history, artist info (tags, similar artists), user profile/session validation |
| `Discogs` / `Discogs.API`         | discogs.com          | 2000 ms    | Artist profiles, images                                                                             |
| `Wikipedia` / `Wikipedia.API`     | wikipedia.org        | 1000 ms    | Artist biographies                                                                                  |
| `BraveSearch` / `BraveSearch.API` | search.brave.com     | 1000 ms    | Cover art and artist image search                                                                   |
| `OpenAI` / `OpenAI.API`           | api.openai.com       | 250 ms     | Text embeddings for similarity, streaming chat via Responses API (gpt-4.1/gpt-5.1 + web search)     |
| `MusicLibrary.Mailer`             | Mailgun (via Swoosh) | —          | Transactional email delivery (error notifications, daily digest)                                    |

Each has a `Config` module reading from application env. All HTTP clients use `Req` with
per-API rate limiting (`Req.RateLimiter`, ETS-backed). In tests, all HTTP calls are
stubbed via `Req.Test` (configured in `config/test.exs`).

Each API also has an `API.ErrorResponse` module (e.g. `MusicBrainz.API.ErrorResponse`,
`OpenAI.API.ErrorResponse`) implementing the `MusicLibrary.ErrorResponse` behaviour,
so workers can uniformly classify HTTP failures as transient (snooze) or permanent
(cancel) via `MusicLibrary.Worker.ErrorHandler`. Retry/reset headers are parsed into
clamped snooze delays when providers expose them. Per-API overrides capture API-specific
quirks — e.g. MusicBrainz uses HTTP 503 as the rate-limit signal, and OpenAI splits
HTTP 429 into `:rate_limit` vs `:auth_error` by reading the body `code`
(`insufficient_quota` → permanent).

---

## Oban Workers (lib/music_library/worker/)

### Queues

| Queue          | Concurrency | Purpose                                                             |
| -------------- | ----------- | ------------------------------------------------------------------- |
| `default`      | 10          | General async tasks                                                 |
| `heavy_writes` | 1           | DB-intensive or serialized operations                               |
| `openai`       | 3           | OpenAI calls (rate-limited at Req layer via `Req.RateLimiter`)      |
| `music_brainz` | 3           | MusicBrainz calls (rate-limited at Req layer via `Req.RateLimiter`) |
| `discogs`      | 3           | Discogs calls (rate-limited at Req layer via `Req.RateLimiter`)     |
| `wikipedia`    | 3           | Wikipedia calls                                                     |
| `last_fm`      | 3           | Last.fm calls (rate-limited at Req layer via `Req.RateLimiter`)     |

### Plugins (prod)

| Plugin                   | Config                      | Purpose                                                    |
| ------------------------ | --------------------------- | ---------------------------------------------------------- |
| `Oban.Plugins.Pruner`    | `max_age: 604800` (7 days)  | Prune completed/cancelled/discarded jobs older than 7 days |
| `Oban.Plugins.Reindexer` | `schedule: "@weekly"`       | Weekly reindex of Oban tables for query performance        |
| `Oban.Plugins.Cron`      | `timezone: "Europe/London"` | Scheduled recurring workers (see Cron Workers table)       |

### On-Demand Workers

| Worker                              | Queue        | Trigger                                                                     |
| ----------------------------------- | ------------ | --------------------------------------------------------------------------- |
| `FetchArtistInfo`                   | default      | Artist page visit / import (also fetches Last.fm data inline)               |
| `FetchArtistLastFmData`             | last_fm      | Manual / batch                                                              |
| `FetchArtistImage`                  | heavy_writes | Artist info fetched                                                         |
| `RefreshCover`                      | heavy_writes | Manual action / import                                                      |
| `ImportFromMusicbrainzRelease`      | music_brainz | Barcode scan batch import (2+ new records)                                  |
| `ImportFromMusicbrainzReleaseGroup` | music_brainz | Cart-style multi-record import in AddRecord component (2+ records selected) |
| `PopulateGenres`                    | openai       | Manual action (chains → GenerateRecordEmbedding)                            |
| `GenerateRecordEmbedding`           | openai       | Manual / after genre population (delegates to Similarity, skips unchanged)  |
| `RecordRefreshMusicBrainzData`      | music_brainz | Manual / batch                                                              |
| `ArtistRefreshMusicBrainzData`      | music_brainz | Manual / batch                                                              |
| `ArtistRefreshDiscogsData`          | discogs      | Manual / batch                                                              |
| `ArtistRefreshWikipediaData`        | wikipedia    | Manual / batch                                                              |
| `PruneArtistInfo`                   | default      | Record deleted (cleanup orphaned artist data)                               |
| `RecordRefreshAllMusicBrainzData`   | music_brainz | Manual / cron (bulk refresh via Records.Batch)                              |
| `RecordGenerateAllEmbeddings`       | heavy_writes | Manual / cron (bulk generate via Records.Batch)                             |
| `ArtistRefreshAllMusicBrainzData`   | music_brainz | Manual / cron (bulk refresh via Artists.Batch)                              |
| `ArtistRefreshAllDiscogsData`       | discogs      | Manual / cron (bulk refresh via Artists.Batch)                              |
| `ArtistRefreshAllWikipediaData`     | wikipedia    | Manual / cron (bulk refresh via Artists.Batch)                              |
| `RefreshScrobbles`                  | last_fm      | Cron / manual (fetch recent Last.fm scrobbles)                              |
| `BackfillScrobbledTracks`           | heavy_writes | Manual (self-chaining batch import)                                         |
| `SendRecordsOnThisDayEmail`         | default      | Cron (daily "records on this day" email)                                    |

### Cron Workers

| Schedule           | Worker                            | Queue        |
| ------------------ | --------------------------------- | ------------ |
| Every 12h          | `ApplyScrobbleRules`              | heavy_writes |
| Every 12h          | `PruneAssetCache`                 | default      |
| Daily 2 AM         | `PruneAssets`                     | default      |
| Daily 3 AM         | `RepoVacuum`                      | heavy_writes |
| Daily 4 AM         | `RepoOptimize`                    | heavy_writes |
| Monthly 1st, 6 AM  | `RecordRefreshAllMusicBrainzData` | music_brainz |
| Monthly 1st, 7 AM  | `RecordGenerateAllEmbeddings`     | heavy_writes |
| Monthly 1st, 8 AM  | `ArtistRefreshAllMusicBrainzData` | music_brainz |
| Monthly 1st, 9 AM  | `ArtistRefreshAllDiscogsData`     | discogs      |
| Monthly 1st, 10 AM | `ArtistRefreshAllWikipediaData`   | wikipedia    |
| Daily 7 AM         | `SendRecordsOnThisDayEmail`       | default      |
| Every 5 min        | `RefreshScrobbles`                | last_fm      |

---

## PubSub Topics

| PubSub           | Topic Pattern              | Message                  | Used By                                                                                                                                                                                                                                                                                                                                               |
| ---------------- | -------------------------- | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `:music_library` | `"records:#{id}"`          | `{:update, record}`      | CollectionLive.Show, WishlistLive.Show — subscribe in `handle_params`, unsubscribe on navigation. `handle_info({:update, record})` matches record ID against socket and guards against applying background updates during `:edit` `live_action` (skips assign, shows warning toast) to prevent worker changes from overwriting in-progress form edits |
| `:music_library` | `"records:index_changed"`  | `:records_index_changed` | CollectionLive.Index, WishlistLive.Index — auto-refresh when background import completes                                                                                                                                                                                                                                                              |
| `:music_library` | `"listening_stats:update"` | `%{track_count: n}`      | StatsLive.Index, ScrobbledTracksLive.Index — new scrobbles arrived                                                                                                                                                                                                                                                                                    |

---

## Web Layer (lib/music_library_web/)

### Router Structure

All authenticated routes live inside a single `live_session` with three `on_mount` hooks:

- `StaticAssets` — detects app updates, shows toast
- `GetTimezone` — reads timezone from connect params
- `ShowToast` — enables `put_toast!/2` in LiveViews

### LiveViews

| LiveView                        | Route                                   | Purpose                                                              |
| ------------------------------- | --------------------------------------- | -------------------------------------------------------------------- |
| `StatsLive.Index`               | `/`                                     | Dashboard: counts, recent activity, records on this day              |
| `CollectionLive.Index`          | `/collection`                           | Browse/search collected records (grid/list, paginated)               |
| `CollectionLive.Show`           | `/collection/:id`                       | Record detail: metadata, scrobbles, similar, colors                  |
| `WishlistLive.Index`            | `/wishlist`                             | Browse/search wishlisted records                                     |
| `WishlistLive.Show`             | `/wishlist/:id`                         | Wishlist record detail with store links                              |
| `ArtistLive.Show`               | `/artists/:musicbrainz_id`              | Artist bio, discography, similar artists                             |
| `RecordSetLive.Index`           | `/record-sets`                          | Browse/manage curated record sets                                    |
| `RecordSetLive.Show`            | `/record-sets/:id`                      | Set detail with reorderable items                                    |
| `ScrobbleLive.Index`            | `/scrobble`                             | Search MusicBrainz release groups to scrobble                        |
| `ScrobbleLive.ReleaseGroupShow` | `/scrobble/:rg_id`                      | List releases within a release group                                 |
| `ScrobbleLive.ReleaseShow`      | `/scrobble/:rg_id/releases/:release_id` | Select tracks and scrobble (uses `Release` live_component)           |
| `ScrobbledTracksLive.Index`     | `/scrobbled-tracks`                     | Browse/search Last.fm history                                        |
| `ScrobbleRulesLive.Index`       | `/scrobble-rules`                       | Browse/search/sort scrobble remapping rules (paginated, 50 per page) |
| `OnlineStoreTemplateLive.Index` | `/online-store-templates`               | Manage store URL templates                                           |
| `MaintenanceLive.Index`         | `/maintenance`                          | Admin: batch jobs, DB maintenance, Last.fm connection                |

### LiveComponents

| Component                      | Used In                                                                       | Purpose                                                                                       |
| ------------------------------ | ----------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| `RecordForm`                   | Collection/Wishlist (edit)                                                    | Record editing: cover search, genre autocomplete, color picker, file upload                   |
| `ArtistLive.Form`              | ArtistLive.Show                                                               | Edit artist image (upload + Brave image search)                                               |
| `RecordSetLive.Form`           | RecordSetLive.Index                                                           | Create/edit record set                                                                        |
| `RecordSetLive.RecordPicker`   | RecordSetLive.Show                                                            | Search and add records to set                                                                 |
| `ScrobbledTracksLive.Form`     | ScrobbledTracksLive.Index                                                     | Edit scrobbled track                                                                          |
| `ScrobbleRulesLive.Form`       | ScrobbleRulesLive.Index                                                       | Create/edit scrobble rule                                                                     |
| `ScrobbleRulePicker`           | ScrobbledTracksLive.Index, StatsLive.Index                                    | Search records and create scrobble rules inline                                               |
| `OnlineStoreTemplateLive.Form` | OnlineStoreTemplateLive.Index                                                 | Create/edit store template                                                                    |
| `StatsLive.TopByPeriod`        | StatsLive.TopAlbums, StatsLive.TopArtists                                     | Generic period-tabbed stats display (7d, 30d, 90d, 1y, all-time)                              |
| `StatsLive.TopAlbums`          | StatsLive.Index                                                               | Top albums by period (uses TopByPeriod)                                                       |
| `StatsLive.TopArtists`         | StatsLive.Index                                                               | Top artists by period (uses TopByPeriod)                                                      |
| `UniversalSearchLive.Index`    | Layout (global)                                                               | Cmd+K search modal with quick actions (add to wishlist/collection, scrobble, collection chat) |
| `Chat`                         | CollectionLive.Index, CollectionLive.Show, WishlistLive.Show, ArtistLive.Show | AI chat sheet (OpenAI streaming, configurable per entity)                                     |
| `Notes`                        | CollectionLive.Show, WishlistLive.Show, ArtistLive.Show                       | Markdown note rendering and editing                                                           |
| `AddRecord`                    | CollectionLive.Index, WishlistLive.Index                                      | MusicBrainz import interface                                                                  |
| `BarcodeScanner`               | CollectionLive.Index                                                          | Barcode scanning UI (uses barcode-detector JS)                                                |
| `Release`                      | CollectionLive.Show, ScrobbleLive.ReleaseShow                                 | MusicBrainz release display with scrobble (form-based with auto-recovery)                     |

### Shared Component Modules (lib/music_library_web/components/)

| Module               | Purpose                                                                                                                              |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| `CoreComponents`     | Forms, buttons, icons, tables, flash messages                                                                                        |
| `Layouts`            | Application layout templates, navigation components (`dropdown_nav/1`)                                                               |
| `RecordComponents`   | Record cards, cover images, artist images, labels, grids, release status badges, and shared record show-page sections/actions/sheets |
| `ChartComponents`    | Charts for stats dashboard                                                                                                           |
| `StatsComponents`    | Stats dashboard widgets (`section/1` layout, counters, album preview, records on this day)                                           |
| `ScrobbleComponents` | Scrobble activity displays: status badges, import dropdowns, metadata tooltips, and record-matching UI                               |
| `SearchComponents`   | Search result rendering                                                                                                              |
| `CartComponents`     | `cart_sidebar/1` — shared cart aside used by `AddRecord` and `BarcodeScanner`                                                        |
| `Pagination`         | Pagination UI and logic                                                                                                              |

### Web Utility Modules (lib/music_library_web/)

| Module                      | Purpose                                                                                                                                      |
| --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------- |
| `ErrorMessages`             | Maps internal error terms (atoms, structs) to user-friendly gettext strings via `friendly_message/1`                                         |
| `Markdown`                  | Markdown-to-HTML conversion (MDEx with ammonia sanitization) with `[[double bracket]]` link syntax and streaming document support for chat   |
| `Duration`                  | Milliseconds to human-readable duration formatting                                                                                           |
| `Auth`                      | Authentication plugs: login password check, API token validation, session enforcement                                                        |
| `ArtistLive.Biography`      | Artist biography building/rendering from Wikipedia and Last.fm data                                                                          |
| `LiveHelpers.Params`        | URL query param parsing: pagination, search query, sort order, display mode, fallback index                                                  |
| `LiveHelpers.IndexActions`  | Shared index page logic (search, pagination, import, delete, display mode) for Collection/Wishlist index pages, parameterized by config map  |
| `LiveHelpers.RecordActions` | Shared record action handlers (refresh cover, genres, embeddings, MusicBrainz data) for Collection/Wishlist show pages                       |
| `LiveHelpers.RecordShow`    | Shared Collection/Wishlist show-page loading, page titles, delete navigation, scrobble async handling, and background record update handling |
| —                           | Logster v2 handles `[:phoenix, :socket_connected]` telemetry — not a custom module                                                           |

### Controllers

| Controller             | Routes                                                                                                                                                       | Purpose                                                                                                                       |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- |
| `SessionController`    | `/login`, `/sessions/create`                                                                                                                                 | Login/logout                                                                                                                  |
| `HealthController`     | `/health`                                                                                                                                                    | Health check                                                                                                                  |
| `LastFmController`     | `/auth/last_fm/callback`                                                                                                                                     | Last.fm OAuth                                                                                                                 |
| `AssetController`      | `/assets/:transform_payload`, `/public/assets/:transform_payload`, `/api/v1/assets/:transform_payload`                                                       | Serve images with transforms (public route for emails, API route requires token)                                              |
| `CollectionController` | `/api/v1/collection/*`, `POST /api/v1/collection/:record_id/scrobble`                                                                                        | JSON API for collection queries (search with `?q=`, returns 4 cover sizes), and scrobbling records from Presto                |
| `ErrorController`      | `/api/v1/errors`, `/api/v1/errors/:id`, `/api/v1/errors/:id/mute`, `/api/v1/errors/:id/unmute`, `/api/v1/errors/:id/resolve`, `/api/v1/errors/:id/unresolve` | JSON API for production error queries and mutations (requires Bearer token); POST endpoints for mute/unmute/resolve/unresolve |

---

## Frontend (assets/)

- **Bundler**: esbuild
- **CSS**: Tailwind CSS + Fluxon UI component library
- **JS entry**: `assets/js/app.js`

### JS Hooks

| Hook                        | Type                                 | Purpose                                                                            |
| --------------------------- | ------------------------------------ | ---------------------------------------------------------------------------------- |
| `FormatNumber`              | External (`assets/js/hooks/`)        | Client-side number formatting                                                      |
| `UniversalSearchNavigation` | External                             | Keyboard navigation in search modal (via `create-navigation-hook` factory)         |
| `RecordPickerNavigation`    | External                             | Keyboard navigation in record picker (via `create-navigation-hook` factory)        |
| `RulePickerNavigation`      | External                             | Keyboard navigation in scrobble rule picker (via `create-navigation-hook` factory) |
| `SortableList`              | External (`assets/js/hooks/`)        | Drag-and-drop reordering of record set items (uses sortablejs)                     |
| `LiveToast`                 | External (via `createLiveToastHook`) | Toast notification rendering                                                       |
| Various `.ColocatedHooks`   | Colocated (in .heex)                 | Inline hooks prefixed with `.` (includes `.ScrollBottom` for Chat)                 |

### JS Event Listeners (app.js)

All events are namespaced with `music_library:` prefix.

| Event                      | Action                                                                                                        |
| -------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `music_library:clipcopy`   | Copy text to clipboard                                                                                        |
| `music_library:scroll_top` | Scroll window to top                                                                                          |
| `music_library:confetti`   | Trigger canvas-confetti animation                                                                             |
| `music_library:download`   | Decode base64 blob and trigger browser file download (dispatched via `push_event`, prefixed `phx:` on client) |

### NPM Dependencies

- `barcode-detector` — Barcode scanning API
- `canvas-confetti` — Confetti animation
- `sortablejs` — Drag-and-drop list reordering
- `live_toast` — Toast notifications (local dep)
- `@tailwindcss/typography` (dev) — Prose CSS classes for markdown rendering

---

## Testing Patterns

### Test Support

| Module            | Purpose                                     |
| ----------------- | ------------------------------------------- |
| `ConnCase`        | HTTP test setup, auto-logged-in session     |
| `DataCase`        | Database test setup with Ecto sandbox       |
| `LiveTestHelpers` | `escape/1` for HTML-escaped text assertions |

### Fixture Modules (test/support/fixtures/)

| Module                                      | Creates                       |
| ------------------------------------------- | ----------------------------- |
| `MusicLibrary.RecordsFixtures`              | Records with MusicBrainz data |
| `MusicLibrary.RecordSetsFixtures`           | Record sets with items        |
| `MusicLibrary.OnlineStoreTemplatesFixtures` | Store templates               |
| `MusicLibrary.ArtistInfoFixtures`           | ArtistInfo records            |
| `ScrobbleRulesFixtures`                     | Scrobble rules                |
| `ScrobbledTracksFixtures`                   | Last.fm tracks                |
| `Discogs.ArtistFixtures`                    | Discogs API responses         |
| `LastFm.ArtistFixtures`                     | Last.fm API responses         |
| `MusicBrainz.*Fixtures`                     | MusicBrainz API responses     |
| `Wikipedia.Fixtures`                        | Wikipedia API responses       |

### Test Styles

1. **PhoenixTest** (`visit`, `assert_has`, `click_button`, `click_link`) — used for page-level
   LiveView tests (Collection, Wishlist, Stats, etc.)
2. **Phoenix.LiveViewTest** (`live/2`, `form/3`, `render_submit/1`, `element/2`, `render_click/1`) —
   needed for LiveComponent interactions (`phx-target={@myself}`)
3. **Context tests** — standard ExUnit with DataCase

### SQLite Test Gotchas

- `utc_datetime` has second-level precision — rapid inserts get identical timestamps
- Use `Repo.update_all` to manually set timestamps for deterministic ordering tests
- External APIs stubbed via `Req.Test` (see `config/test.exs`)
- Oban runs in manual testing mode (jobs don't auto-execute)

---

## Key Conventions

- **Streams everywhere**: Collection/Wishlist lists, recent activity, record sets, scrobbled tracks
  all use LiveView streams (not assigns) for memory efficiency
- **Async enrichment**: Record/artist import triggers a cascade of Oban workers for metadata,
  covers, colors, embeddings — all non-blocking
- **Search**: FTS5 for text search, custom `SearchParser` for structured queries, sqlite-vec
  for similarity
- **Record lifecycle**: `purchased_at` distinguishes collection (set) from wishlist (nil)
- **`use MusicLibraryWeb, :live_view`** imports: Phoenix.LiveView, Fluxon, Gettext, LiveToast,
  CoreComponents, Phoenix.HTML, verified routes, JS alias
- **`use MusicLibraryWeb, :live_component`** additionally imports `put_toast!/2`
- **Telemetry buffering**: `Telemetry.Storage` keeps incoming datapoints in an in-memory map
  keyed by metric and flushes to SQLite on a 5 s timer, on shutdown, and synchronously when
  `metrics_history/1` is called (only for the requested metric). Keeps the cast path O(1) and
  the dashboard read path consistent.

---

## Project Tooling (pi Extensions)

Project-local pi extensions live under `.pi/extensions/` and provide developer-facing
CLI tools and LLM tools. They are TypeScript modules loaded by the pi coding agent.

| Extension              | Command        | LLM Tools                                                                                              | Purpose                                                                       |
| ---------------------- | -------------- | ------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| `sensitive-file-guard` | —              | — (event-based)                                                                                        | Blocks access to sensitive file paths and commands via tool_call interception |
| `s3-browser`           | `/backups`     | —                                                                                                      | Lists Litestream S3 backup files                                              |
| `prod-errors`          | `/prod-errors` | `fetch_production_errors`, `fetch_production_error`                                                    | Browse and manage production error tracker data                               |
| `prod-logs`            | `/prod-logs`   | `fetch_production_logs`                                                                                | Fetch and browse production log output via Coolify API                        |
| `format-on-edit`       | —              | — (event-based)                                                                                        | Auto-formats files on edit (prettier, mix format)                             |
| `ci-browser`           | `/ci`          | `ci_list_runs`, `ci_view_run`, `ci_find_current_branch_run`, `ci_watch_run`, `ci_watch_current_branch` | Browse and monitor GitHub Actions CI runs via `gh` CLI                        |

Tests for pi extensions run via `scripts/dev/pi-test` and `.github/workflows/pi.yml`.
