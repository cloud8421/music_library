# Architecture Summary

> **Maintenance rule**: Update this file whenever you add, remove, or restructure modules,
> schemas, contexts, workers, routes, or external integrations. Keep descriptions factual
> and concise. This file exists to accelerate future iteration — treat it as a living map.

## Overview

Phoenix LiveView application for managing a personal music collection and wishlist.
Uses SQLite (via `ecto_sqlite3`) with two databases: one for the app, one for background
jobs (Oban). All schemas use `binary_id` primary keys.

Key capabilities:
- Browse/search collected and wishlisted records
- Import metadata from MusicBrainz, enrich with Discogs/Wikipedia/Last.fm
- Scrobble tracks to Last.fm, import listening history
- Similarity search via OpenAI embeddings + sqlite-vec
- AI-powered record chat via OpenAI streaming with web search
- Barcode scanning for quick imports
- Encrypted secret storage (Cloak)

**Elixir ~> 1.14, Phoenix ~> 1.8, LiveView ~> 1.1, SQLite3**

---

## Supervision Tree

```
MusicLibrary.Application (one_for_one)
├── MusicLibrary.Vault           # Cloak encryption vault
├── MusicLibrary.Repo            # Main SQLite repo
├── MusicLibrary.BackgroundRepo  # Oban SQLite repo (separate DB)
├── MusicLibraryWeb.Telemetry    # Telemetry supervisor
│   ├── Telemetry.Storage        # Metrics storage (circular buffer)
│   └── :telemetry_poller        # 30s periodic measurements
├── Oban                         # Background job engine
├── Ecto.Migrator                # Auto-migration on boot
├── Task.Supervisor (MusicLibrary.TaskSupervisor)
├── Phoenix.PubSub (:music_library)
├── LastFm.Supervisor (one_for_one)
│   ├── Phoenix.PubSub (:last_fm) # Last.fm-specific PubSub
│   └── LastFm.Refresh            # GenServer, periodic scrobble fetch
└── MusicLibraryWeb.Endpoint
```

---

## Database & Repos

| Repo | DB file (dev) | Purpose |
|------|---------------|---------|
| `MusicLibrary.Repo` | `data/music_library_dev.db` | All application data |
| `MusicLibrary.BackgroundRepo` | `data/music_library_background_dev.db` | Oban job queue |

SQLite extensions loaded at runtime: `unicode`, `vec0` (vector search).

FTS5 virtual table `records_search_index` auto-synced via database triggers — do not
write to it directly; insert/update the `records` table instead.

---

## Schemas

| Schema | Table | PK | Key Fields |
|--------|-------|----|------------|
| `Records.Record` | `records` | `id` (binary_id) | title, type, format, cover_url, cover_hash, musicbrainz_id, genres[], release_date, purchased_at, dominant_colors[], embeds_many :artists |
| `Records.RecordEmbedding` | `record_embeddings` | `id` | embedding (Float32 vector), text_representation, belongs_to :record |
| `Records.SearchIndex` | `records_search_index` | `id` | FTS5 mirror of records (virtual, trigger-synced) |
| `Records.RecordRelease` | `record_releases` | none | record_id, release_id, cover_hash, purchased_at — read-only, no PK |
| `Records.ArtistRecord` | `artist_records` | composite | musicbrainz_id, record_id — DB view joining artists to records |
| `Artists.Artist` | — | — | Embedded schema (name, sort_name, musicbrainz_id, joinphrase) |
| `Artists.ArtistInfo` | `artist_infos` | `id` | musicbrainz_data, discogs_data, wikipedia_data, lastfm_data, image_data_hash |
| `Assets.Asset` | `assets` | `hash` (SHA256) | content (binary), format, properties (map) |
| `Notes.Note` | `notes` | `id` | entity (:record/:artist), content, musicbrainz_id |
| `RecordSets.RecordSet` | `record_sets` | `id` | name, description, has_many :items |
| `RecordSets.RecordSetItem` | `record_set_items` | `id` | position, belongs_to :record_set, belongs_to :record |
| `ScrobbleRules.ScrobbleRule` | `scrobble_rules` | `id` (integer) | type (:album/:artist), match_value, target_musicbrainz_id, enabled |
| `OnlineStoreTemplates.OnlineStoreTemplate` | `online_store_templates` | `id` | name, url_template, enabled |
| `Secrets.Secret` | `secrets` | `name` (string) | value (encrypted binary) |

Last.fm schemas (separate, not Ecto-persisted to main DB):
- `LastFm.Track` — scrobbled tracks stored in Last.fm's own tables via `LastFm.Feed`
- `LastFm.Album`, `LastFm.Artist` — parsed API responses

---

## Contexts (lib/music_library/)

| Context | Schemas | Responsibility |
|---------|---------|---------------|
| `Records` | Record, RecordEmbedding, SearchIndex | CRUD, search, import from MusicBrainz, cover/genre/embedding management, PubSub notifications |
| `Collection` | Record (via SearchIndex) | Querying collected records (purchased_at != nil), stats |
| `Wishlist` | Record (via SearchIndex) | Querying wishlisted records (purchased_at is nil) |
| `Artists` | ArtistInfo, ArtistRecord | Artist metadata from MusicBrainz/Discogs/Wikipedia/Last.fm, images |
| `Assets` | Asset | Binary asset storage (covers, artist images), cache tracking |
| `Notes` | Note | Free-text notes for records and artists |
| `RecordSets` | RecordSet, RecordSetItem | User-curated record groupings with ordering |
| `ScrobbleRules` | ScrobbleRule | Rules to remap Last.fm scrobble data to correct MusicBrainz IDs |
| `ScrobbleActivity` | (LastFm.Track, ArtistRecord) | Scrobbling releases, track CRUD, data quality diagnostics |
| `ListeningStats` | (LastFm.Track, ArtistRecord, ArtistInfo) | Read-only listening analytics: scrobble counts, recent activity, top albums/artists by period |
| `OnlineStoreTemplates` | OnlineStoreTemplate | URL templates for buying records online |
| `Search` | (cross-context) | Universal search across collection, wishlist, artists, record sets |
| `Secrets` | Secret | Encrypted key-value storage |
| `BarcodeScan` | (Result struct) | Barcode → MusicBrainz lookup workflow |

---

## Business Logic Modules

| Module | Purpose |
|--------|---------|
| `Records.SearchParser` | Parses search syntax: `artist:X`, `album:X`, `genre:"Y"`, `format:cd`, `type:album`, `purchase_year:2024`, free text |
| `Records.Similarity` | Embedding generation (OpenAI, enriched with Last.fm tags), cosine-distance search (sqlite-vec) |
| `Batch` | Generic batch runner: stream + transaction + error accumulation |
| `Records.Batch` | Batch operations: refresh all MusicBrainz data, generate all embeddings (uses `Batch`) |
| `Artists.Batch` | Batch refresh: MusicBrainz, Discogs, Wikipedia, Last.fm for all artists (uses `Batch`) |
| `Req.RateLimiter` | ETS-backed Req request step enforcing per-API minimum intervals between requests |
| `Assets.Cache` | ETS-based asset cache with TTL |
| `Assets.Image` / `Assets.Transform` | Image processing via Vix (libvips) |
| `Colors.KMeansExtractor` | Color extraction via K-Means clustering (dominant_colors library) |
| `Chat` | Behaviour for streaming AI chat (`stream_response/3` callback) |
| `RecordChat` | Chat implementation for records (OpenAI streaming, web search enabled) |
| `ArtistChat` | Chat implementation for artists (OpenAI streaming, uses Wikipedia/artist context) |
| `Country` | Country code (alpha-2, alpha-3, subdivision, IETF) to flag emoji conversion |
| `FormatNumber` | Number formatting utility |

---

## External API Integrations

| Module | API | Purpose |
|--------|-----|---------|
| `MusicBrainz` / `MusicBrainz.API` | musicbrainz.org | Release/artist metadata, search |
| `LastFm` / `LastFm.API` | last.fm | Scrobbling, listening history, artist info (tags, similar artists) |
| `Discogs` / `Discogs.API` | discogs.com | Artist profiles, images |
| `Wikipedia` / `Wikipedia.API` | wikipedia.org | Artist biographies |
| `BraveSearch` / `BraveSearch.API` | search.brave.com | Cover art and artist image search |
| `OpenAI` / `OpenAI.API` | api.openai.com | Text embeddings for similarity, streaming chat via Responses API (gpt-4.1 + web search) |

Each has a `Config` module reading from application env. In tests, all HTTP calls are
stubbed via `Req.Test` (configured in `config/test.exs`).

---

## Oban Workers (lib/music_library/worker/)

### Queues

| Queue | Concurrency | Purpose |
|-------|-------------|---------|
| `default` | 10 | General async tasks |
| `heavy_writes` | 1 | DB-intensive or serialized operations |
| `music_brainz` | 1 | MusicBrainz calls (rate-limited at Req layer via `Req.RateLimiter`) |
| `discogs` | 1 | Discogs calls (rate-limited at Req layer via `Req.RateLimiter`) |
| `wikipedia` | 1 | Wikipedia calls |
| `last_fm` | 1 | Last.fm calls (rate-limited at Req layer via `Req.RateLimiter`) |

### On-Demand Workers

| Worker | Queue | Trigger |
|--------|-------|---------|
| `FetchArtistInfo` | default | Artist page visit / import (also fetches Last.fm data inline) |
| `FetchArtistLastFmData` | last_fm | Manual / batch |
| `FetchArtistImage` | heavy_writes | Artist info fetched |
| `RefreshCover` | heavy_writes | Manual action / import |
| `PopulateGenres` | heavy_writes | Manual action (chains → GenerateRecordEmbedding) |
| `GenerateRecordEmbedding` | heavy_writes | Manual / after genre population |
| `RecordRefreshMusicBrainzData` | music_brainz | Manual / batch |
| `ArtistRefreshMusicBrainzData` | music_brainz | Manual / batch |
| `ArtistRefreshDiscogsData` | discogs | Manual / batch |
| `ArtistRefreshWikipediaData` | wikipedia | Manual / batch |
| `PruneArtistInfo` | default | Record deleted (cleanup orphaned artist data) |
| `RecordRefreshAllMusicBrainzData` | music_brainz | Manual / cron (bulk refresh via Records.Batch) |
| `RecordGenerateAllEmbeddings` | heavy_writes | Manual / cron (bulk generate via Records.Batch) |
| `ArtistRefreshAllMusicBrainzData` | music_brainz | Manual / cron (bulk refresh via Artists.Batch) |
| `ArtistRefreshAllDiscogsData` | discogs | Manual / cron (bulk refresh via Artists.Batch) |
| `ArtistRefreshAllWikipediaData` | wikipedia | Manual / cron (bulk refresh via Artists.Batch) |
| `LastFm.Worker.BackfillScrobbledTracks` | heavy_writes | Manual (self-chaining batch import) |

### Cron Workers

| Schedule | Worker | Queue |
|----------|--------|-------|
| Every 12h | `ApplyScrobbleRules` | heavy_writes |
| Every 12h | `PruneAssetCache` | default |
| Daily 2 AM | `PruneAssets` | default |
| Daily 3 AM | `RepoVacuum` | heavy_writes |
| Daily 4 AM | `RepoOptimize` | heavy_writes |
| Monthly 1st, 6 AM | `RecordRefreshAllMusicBrainzData` | music_brainz |
| Monthly 1st, 7 AM | `RecordGenerateAllEmbeddings` | heavy_writes |
| Monthly 1st, 8 AM | `ArtistRefreshAllMusicBrainzData` | music_brainz |
| Monthly 1st, 9 AM | `ArtistRefreshAllDiscogsData` | discogs |
| Monthly 1st, 10 AM | `ArtistRefreshAllWikipediaData` | wikipedia |

---

## PubSub Topics

| PubSub | Topic Pattern | Message | Used By |
|--------|---------------|---------|---------|
| `:music_library` | `"records:#{id}"` | `{:update, record}` | CollectionLive.Show, WishlistLive.Show — real-time record updates |
| `:last_fm` | `"feed:update"` | `%{track_count: n}` | StatsLive.Index, ScrobbledTracksLive.Index — new scrobbles arrived |

---

## Web Layer (lib/music_library_web/)

### Router Structure

All authenticated routes live inside a single `live_session` with three `on_mount` hooks:
- `StaticAssets` — detects app updates, shows toast
- `GetTimezone` — reads timezone from connect params
- `ShowToast` — enables `put_toast!/2` in LiveViews

### LiveViews

| LiveView | Route | Purpose |
|----------|-------|---------|
| `StatsLive.Index` | `/` | Dashboard: counts, recent activity, records on this day |
| `CollectionLive.Index` | `/collection` | Browse/search collected records (grid/list, paginated) |
| `CollectionLive.Show` | `/collection/:id` | Record detail: metadata, scrobbles, similar, colors |
| `WishlistLive.Index` | `/wishlist` | Browse/search wishlisted records |
| `WishlistLive.Show` | `/wishlist/:id` | Wishlist record detail with store links |
| `ArtistLive.Show` | `/artists/:musicbrainz_id` | Artist bio, discography, similar artists |
| `RecordSetLive.Index` | `/record-sets` | Browse/manage curated record sets |
| `RecordSetLive.Show` | `/record-sets/:id` | Set detail with reorderable items |
| `ScrobbleLive.Index` | `/scrobble` | Search MusicBrainz releases to scrobble |
| `ScrobbleLive.Show` | `/scrobble/:release_id` | Select tracks and scrobble |
| `ScrobbledTracksLive.Index` | `/scrobbled-tracks` | Browse/search Last.fm history |
| `ScrobbleRulesLive.Index` | `/scrobble-rules` | Manage scrobble remapping rules |
| `OnlineStoreTemplateLive.Index` | `/online-store-templates` | Manage store URL templates |
| `MaintenanceLive.Index` | `/dev/maintenance` | Admin: batch jobs, DB maintenance (conditional on `:monitoring_routes` config, outside main `live_session`) |

### LiveComponents

| Component | Used In | Purpose |
|-----------|---------|---------|
| `RecordForm` | Collection/Wishlist (edit) | Record editing: cover search, genre autocomplete, color picker, file upload |
| `ArtistLive.Form` | ArtistLive.Show | Edit artist image (upload + Brave image search) |
| `RecordSetLive.Form` | RecordSetLive.Index | Create/edit record set |
| `RecordSetLive.RecordPicker` | RecordSetLive.Show | Search and add records to set |
| `ScrobbledTracksLive.Form` | ScrobbledTracksLive.Index | Edit scrobbled track |
| `ScrobbleRulesLive.Form` | ScrobbleRulesLive.Index | Create/edit scrobble rule |
| `OnlineStoreTemplateLive.Form` | OnlineStoreTemplateLive.Index | Create/edit store template |
| `StatsLive.TopAlbums` | StatsLive.Index | Top albums by period (assign_async) |
| `StatsLive.TopArtists` | StatsLive.Index | Top artists by period (assign_async) |
| `UniversalSearchLive.Index` | Layout (global) | Cmd+K search modal |
| `Chat` | CollectionLive.Show, WishlistLive.Show, ArtistLive.Show | AI chat sheet (OpenAI streaming, configurable per entity) |
| `Notes` | CollectionLive.Show, WishlistLive.Show, ArtistLive.Show | Markdown note rendering and editing |

### Shared Component Modules (lib/music_library_web/components/)

| Module | Purpose |
|--------|---------|
| `CoreComponents` | Forms, buttons, icons, tables, flash messages |
| `Layouts` | Application layout templates |
| `RecordComponents` | Record cards, cover images, artist images, labels, grids, shared show-page sections (title, external links, genres, releases, timestamps, debug) |
| `ChartComponents` | SVG charts for stats |
| `StatsComponents` | Stats dashboard widgets |
| `ScrobbleComponents` | Scrobble activity displays |
| `SearchComponents` | Search result rendering |
| `Pagination` | Pagination UI and logic |
| `AddRecord` | MusicBrainz import interface |
| `BarcodeScanner` | Barcode scanning UI (uses barcode-detector JS) |
| `Release` | MusicBrainz release display |

### Web Utility Modules (lib/music_library_web/)

| Module | Purpose |
|--------|---------|
| `Markdown` | Markdown-to-HTML conversion with `[[double bracket]]` link syntax |
| `Duration` | Milliseconds to human-readable duration formatting |
| `LiveHelpers.Params` | Pagination param parsing from URL query params |

### Controllers

| Controller | Routes | Purpose |
|------------|--------|---------|
| `SessionController` | `/login`, `/sessions/create` | Login/logout |
| `HealthController` | `/health` | Health check |
| `LastFmController` | `/auth/last_fm/callback` | Last.fm OAuth |
| `ArchiveController` | `/backup`, `/api/backup` | Database backup download (API route requires token) |
| `AssetController` | `/assets/:transform_payload`, `/api/assets/:transform_payload` | Serve images with transforms (API route requires token) |
| `CollectionController` | `/api/collection/*` | JSON API for collection queries |

---

## Frontend (assets/)

- **Bundler**: esbuild
- **CSS**: Tailwind CSS + Fluxon UI component library
- **JS entry**: `assets/js/app.js`

### JS Hooks

| Hook | Type | Purpose |
|------|------|---------|
| `FormatNumber` | External (`assets/js/hooks/`) | Client-side number formatting |
| `UniversalSearchNavigation` | External | Keyboard navigation in search modal (via `create-navigation-hook` factory) |
| `RecordPickerNavigation` | External | Keyboard navigation in record picker (via `create-navigation-hook` factory) |
| `SortableList` | External (`assets/js/hooks/`) | Drag-and-drop reordering of record set items (uses sortablejs) |
| `LiveToast` | External (via `createLiveToastHook`) | Toast notification rendering |
| Various `.ColocatedHooks` | Colocated (in .heex) | Inline hooks prefixed with `.` (includes `.ScrollBottom` for Chat) |

### JS Event Listeners (app.js)

All events are namespaced with `music_library:` prefix.

| Event | Action |
|-------|--------|
| `music_library:clipcopy` | Copy text to clipboard |
| `music_library:scroll_top` | Scroll window to top |
| `music_library:confetti` | Trigger canvas-confetti animation |

### NPM Dependencies

- `barcode-detector` — Barcode scanning API
- `canvas-confetti` — Confetti animation
- `sortablejs` — Drag-and-drop list reordering
- `live_toast` — Toast notifications (local dep)
- `@tailwindcss/typography` (dev) — Prose CSS classes for markdown rendering

---

## Testing Patterns

### Test Support

| Module | Purpose |
|--------|---------|
| `ConnCase` | HTTP test setup, auto-logged-in session |
| `DataCase` | Database test setup with Ecto sandbox |
| `LiveTestHelpers` | `escape/1` for HTML-escaped text assertions |

### Fixture Modules (test/support/fixtures/)

| Module | Creates |
|--------|---------|
| `MusicLibrary.RecordsFixtures` | Records with MusicBrainz data |
| `MusicLibrary.RecordSetsFixtures` | Record sets with items |
| `MusicLibrary.OnlineStoreTemplatesFixtures` | Store templates |
| `ScrobbleRulesFixtures` | Scrobble rules |
| `ScrobbledTracksFixtures` | Last.fm tracks |
| `Discogs.ArtistFixtures` | Discogs API responses |
| `LastFm.ArtistFixtures` | Last.fm API responses |
| `MusicBrainz.*Fixtures` | MusicBrainz API responses |
| `Wikipedia.Fixtures` | Wikipedia API responses |

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
