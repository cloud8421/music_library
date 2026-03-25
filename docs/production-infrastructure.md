# Production Infrastructure

> **Maintenance rule**: Update this file when infrastructure changes (hosting, databases,
> backups, monitoring, deployment pipeline, external services). Keep it factual and concise.

## Overview

Self-hosted Phoenix application running as a Docker container orchestrated by
[Coolify](https://coolify.io). SQLite for all persistence, Litestream for continuous
backup to S3-compatible object storage. Deployed automatically on every `main` branch
push via GitHub Actions.

**Domain**: `music-library.claudio-ortolina.org`

---

## Hosting

| Component | Technology |
|-----------|-----------|
| Orchestration | Coolify (self-hosted) |
| Container runtime | Docker |
| SSL termination | Coolify reverse proxy |
| HTTP redirect | HTTP 301 → HTTPS (enforced by app config) |

The Docker image is a multi-stage build:

1. **Builder** — `hexpm/elixir:1.20.0-rc.3-erlang-28.4.1-debian-trixie-20260316-slim` with
   Node.js 24, compiles deps, builds assets (`mix assets.deploy`), generates an OTP release.
2. **Runner** — `debian:trixie-20260316-slim` with minimal runtime deps (`libstdc++6`,
   `openssl`, `libncurses6`, `ca-certificates`). Runs as unprivileged `nobody` user.

Fluxon UI (licensed dependency) is fetched during build via Docker build secrets
(`FLUXON_LICENSE_KEY`, `FLUXON_KEY_FINGERPRINT`).

---

## Databases

Three separate SQLite databases, each managed by its own Ecto repo:

| Repo | Purpose | Cache size | Pool size |
|------|---------|------------|-----------|
| `MusicLibrary.Repo` | Application data | 128 MB | `$POOL_SIZE` (default 5) |
| `MusicLibrary.BackgroundRepo` | Oban job queue | 16 MB | `$POOL_SIZE` (default 5) |
| `MusicLibrary.TelemetryRepo` | Persistent telemetry metrics | 4 MB | 2 |

All databases use incremental auto-vacuum. Paths are configured via environment variables
(`DATABASE_PATH`, `BACKGROUND_DATABASE_PATH`, `TELEMETRY_DATABASE_PATH`).

SQLite extensions loaded at runtime: `unicode`, `vec0` (vector search).

### Scheduled maintenance

| Schedule | Worker | Purpose |
|----------|--------|---------|
| Daily 3 AM | `RepoVacuum` | Reclaim unused space |
| Daily 4 AM | `RepoOptimize` | Run `PRAGMA optimize` |

---

## Backups

### Litestream (continuous)

Configured inline in `compose.yaml`. Runs as a separate Docker Compose service
(`litestream/litestream`) sharing the database volume.

| Setting | Value |
|---------|-------|
| S3 endpoint | `https://nbg1.your-objectstorage.com` |
| Bucket | `ffmusiclibrary` |
| Sync interval | 24 hours |
| Snapshot interval | 24 hours |
| Retention | 168 hours (1 week) |

Credentials via environment: `LITESTREAM_ACCESS_KEY_ID`, `LITESTREAM_SECRET_ACCESS_KEY`.

### Manual backup

`mise run prod:backup` pulls the production database via `rsync` and saves it locally
as `data/music_library_prod_<timestamp>.db`. Old backups can be cleaned with
`mise run prod:prune-backups`.

---

## Deployment Pipeline

### CI/CD (GitHub Actions)

Workflow: `.github/workflows/test_and_deploy.yml`

Triggers: push to `main`/tags, pull requests, manual `workflow_dispatch`.
Concurrency control cancels in-progress runs for the same ref.
Uses `mise` (via `jdx/mise-action@v4`) for tool version management.

```
Push to main (or PR / manual dispatch)
  ├── Lint (format, gettext, credo, sobelow)
  ├── Test (mix test with partitioning)
  └── Deploy (requires GitHub environment approval, main branch only)
        ├── Trigger deployment via Coolify API (hurl)
        ├── Wait for container health check
        └── Run post-deploy verification (test/prod.hurl)
```

A manual verification workflow (`.github/workflows/verify.yml`) can be triggered via
`workflow_dispatch` to re-run production checks without deploying.

### Post-deploy verification

`test/prod.hurl` checks:

- HTTP → HTTPS redirect
- API authentication enforcement
- Valid API responses with auth token
- Dev routes require login
- Bot scanner paths (`wp-admin`, `.env`, `xmlrpc`) return 404

### Deployment credentials

| Secret/Variable | Purpose |
|-----------------|---------|
| `COOLIFY_TOKEN` | API authentication (GitHub secret) |
| `COOLIFY_HOST` | Coolify server address (GitHub variable) |
| `COOLIFY_APP_UUID` | Application identifier (GitHub variable) |

---

## Environment Variables

### Required

| Variable | Purpose |
|----------|---------|
| `DATABASE_PATH` | Absolute path to main SQLite database |
| `BACKGROUND_DATABASE_PATH` | Absolute path to background jobs database |
| `TELEMETRY_DATABASE_PATH` | Absolute path to telemetry database |
| `SECRET_KEY_BASE` | Phoenix secret (`mix phx.gen.secret`) |
| `CLOAK_ENCRYPTION_KEY` | Base64-encoded 32-byte AES key for encrypted secrets |
| `LOGIN_PASSWORD` | Web login password |
| `API_TOKEN` | Bearer token for API endpoints |
| `MAILGUN_API_KEY` | Mailgun API key |

### Optional

| Variable | Default | Purpose |
|----------|---------|---------|
| `SERVICE_FQDN_WEB` | `example.com` | Application domain |
| `PORT` | `4000` | HTTP listen port |
| `POOL_SIZE` | `5` | Database connection pool size |
| `MAILGUN_DOMAIN` | `mailgun.fullyforged.com` | Mailgun sending domain |
| `DEFAULT_TIMEZONE` | `Europe/London` | Application timezone |
| `OPENAI_KEY` | — | OpenAI API (embeddings, chat) |
| `DISCOGS_PERSONAL_ACCESS_TOKEN` | — | Discogs API |
| `BRAVE_SEARCH_API_KEY` | — | Brave Search API |
| `LAST_FM_API_KEY` | — | Last.fm API |
| `LAST_FM_SHARED_SECRET` | — | Last.fm scrobbling auth |
| `LAST_FM_USER` | — | Last.fm username |

---

## OTP Release

Standard Mix release. Entry point: `rel/overlays/bin/server` (sets `PHX_SERVER=true`).

Migrations run automatically on boot via `Ecto.Migrator` in the supervision tree.
A standalone `rel/overlays/bin/migrate` script is also available for manual use.

ERL_FLAGS: `+JPperf true` (JIT performance monitoring).

---

## Monitoring & Observability

### Health check

`GET /health` — queries the main database, returns 200 or 500. Used by Docker health
checks and post-deploy verification.

### Error tracking

`ErrorTracker` with email notifications via Mailgun:

- Listens to `:error_tracker` telemetry events
- Throttles repeated error notifications
- Non-actionable errors (bot scanners, `NoRouteError`) filtered via `ErrorIgnorer`
- Muted errors skip email notifications

### Telemetry

SQLite-backed persistent metrics (`MusicLibraryWeb.Telemetry.Storage`) with 30-second
polling interval. Tracks:

- Database query times (total, query, queue)
- External API request latency (Finch)
- Rate limiter throttle durations
- Asset cache hit/miss
- Oban job metrics (enqueue, execute, attempt, discard)
- Error tracker counters

### Dashboards (behind auth)

- Phoenix LiveDashboard (`/dev/dashboard`)
- Oban Web (`/dev/oban`)
- ErrorTracker (`/dev/errors`)

---

## Email

Mailgun via Swoosh (`Swoosh.Adapters.Mailgun`).

| Setting | Value |
|---------|-------|
| From | `postmaster@mailgun.fullyforged.com` |
| To | `claudio@fullyforged.com` |

Used for error notifications and the daily "records on this day" digest email.

---

## External API Integrations

All HTTP clients use `Req` with per-API rate limiting (`Req.RateLimiter`, ETS-backed).

| API | Rate limit | Purpose |
|-----|-----------|---------|
| MusicBrainz | 500 ms cooldown | Release/artist metadata, search |
| Last.fm | 500 ms cooldown | Scrobbling, listening history, artist tags |
| Discogs | 1000 ms cooldown | Artist profiles, images |
| Wikipedia | 1000 ms cooldown | Artist biographies |
| Brave Search | 1000 ms cooldown | Cover art, artist image search |
| OpenAI | — | Text embeddings (similarity), streaming chat |

---

## Background Jobs

Oban with `Oban.Engines.Lite` (SQLite-backed, process-based).

### Queues

| Queue | Concurrency | Purpose |
|-------|-------------|---------|
| `default` | 10 | General async tasks |
| `heavy_writes` | 1 | Serialized DB-intensive operations |
| `music_brainz` | 1 | MusicBrainz API calls |
| `discogs` | 1 | Discogs API calls |
| `wikipedia` | 1 | Wikipedia API calls |
| `last_fm` | 1 | Last.fm API calls |

### Plugins

- **Pruner**: Removes completed/cancelled/discarded jobs older than 12 hours
- **Reindexer**: Weekly Oban table reindex
- **Cron**: Scheduled jobs (timezone: `Europe/London`)

### Cron schedule

| Schedule | Worker |
|----------|--------|
| Every 12h | `ApplyScrobbleRules` |
| Every 12h | `PruneAssetCache` |
| Daily 2 AM | `PruneAssets` |
| Daily 3 AM | `RepoVacuum` |
| Daily 4 AM | `RepoOptimize` |
| Daily 7 AM | `SendRecordsOnThisDayEmail` |
| Monthly 1st, 6 AM | `RecordRefreshAllMusicBrainzData` |
| Monthly 1st, 7 AM | `RecordGenerateAllEmbeddings` |
| Monthly 1st, 8 AM | `ArtistRefreshAllMusicBrainzData` |
| Monthly 1st, 9 AM | `ArtistRefreshAllDiscogsData` |
| Monthly 1st, 10 AM | `ArtistRefreshAllWikipediaData` |

---

## Encryption

Cloak vault (`MusicLibrary.Vault`) with AES.GCM cipher for at-rest encryption of
secrets stored in the `secrets` table. Key configured via `CLOAK_ENCRYPTION_KEY`
(base64-encoded 32-byte key).

---

## Tool Versions

Defined in `mise.toml`:

| Tool | Version |
|------|---------|
| Elixir | 1.20.0-rc.3-otp-28 |
| Erlang | 28.4.1 |
| Node.js | 24.13.0 |
