# Production Infrastructure

> **Maintenance rule**: Update this file when infrastructure changes (hosting, databases,
> backups, monitoring, deployment pipeline, external services). Keep it factual and concise.

**CRITICAL: under no circumstances you're allowed to interact directly with
production infrastructure without asking the user first.**

## Overview

Self-hosted Phoenix application running as a Docker container orchestrated by
[Coolify](https://coolify.io). SQLite for all persistence, Litestream for continuous
backup to S3-compatible object storage. Deployed automatically on every `main` branch
push via GitHub Actions.

**Domain**: `music-library.claudio-ortolina.org`

---

## Hosting

| Component         | Technology                                |
| ----------------- | ----------------------------------------- |
| Orchestration     | Coolify (self-hosted)                     |
| Container runtime | Docker                                    |
| SSL termination   | Coolify reverse proxy                     |
| HTTP redirect     | HTTP 301 → HTTPS (enforced by app config) |

The Docker image is a multi-stage build:

1. **Builder** — `hexpm/elixir:1.20.1-erlang-29.0.2-debian-trixie-20260518-slim` with
   Node.js 26, compiles deps, builds assets (`mix assets.deploy`), generates an OTP release.
2. **Runner** — `debian:trixie-20260518-slim` with minimal runtime deps (`libstdc++6`,
   `openssl`, `libncurses6`, `ca-certificates`). Runs as unprivileged `nobody` user.

Fluxon UI (licensed dependency) is fetched during build via Docker build secrets
(`FLUXON_LICENSE_KEY`, `FLUXON_KEY_FINGERPRINT`).

---

## Databases

Three separate SQLite databases, each managed by its own Ecto repo:

| Repo                          | Purpose                      | Cache size | Pool size                | Busy timeout |
| ----------------------------- | ---------------------------- | ---------- | ------------------------ | ------------ |
| `MusicLibrary.Repo`           | Application data             | 128 MB     | `$POOL_SIZE` (default 5) | 5,000 ms     |
| `MusicLibrary.BackgroundRepo` | Oban job queue               | 16 MB      | `$POOL_SIZE` (default 5) | —            |
| `MusicLibrary.TelemetryRepo`  | Persistent telemetry metrics | 4 MB       | 2                        | —            |

All databases use incremental auto-vacuum. Paths are configured via environment variables
(`DATABASE_PATH`, `BACKGROUND_DATABASE_PATH`, `TELEMETRY_DATABASE_PATH`).

---

## Backups

### Litestream (continuous)

Configured inline in `compose.yaml`. Runs as a separate Docker Compose service
(`litestream/litestream:0.5.11-scratch`) sharing the database volume.

| Setting       | Value                                                     |
| ------------- | --------------------------------------------------------- |
| S3 endpoint   | `https://nbg1.your-objectstorage.com`                     |
| Bucket        | `ffmusiclibrary`                                          |
| Sync interval | 60 minutes                                                |
| Retention     | 672 hours (28 days)                                       |
| Healthcheck   | `litestream databases` every 30s (timeout 10s, 3 retries) |

Credentials via environment: `LITESTREAM_ACCESS_KEY_ID`, `LITESTREAM_SECRET_ACCESS_KEY`.

### Manual backup

Two manual options are available:

- `mise run prod:backup` — takes an atomic snapshot of the live database on the
  production server using `sqlite3 .backup`, then rsyncs it locally as
  `data/music_library_prod_<timestamp>.db`. Safe under concurrent writes.
- `mise run prod:litestream-backup` — restores the production database locally from
  the S3 Litestream replica. Requires `LITESTREAM_ACCESS_KEY_ID` and
  `LITESTREAM_SECRET_ACCESS_KEY`.

Old backups can be cleaned with `mise run prod:prune-backups`.

---

## Deployment Pipeline

### CI/CD (GitHub Actions)

Workflow: `.github/workflows/test_and_deploy.yml`

Triggers: push to `main`/tags, pull requests, manual `workflow_dispatch`.
Concurrency control cancels in-progress runs for the same ref.
Uses `mise` (via `jdx/mise-action@v4`) for tool version management.

```
Push to main (or PR / manual dispatch)
  ├── Lint (format, gettext, credo, sobelow, mix_audit, shellcheck, docker image, asset build)
  ├── Test (mix test with partitioning, coverage ≥75%)
  └── Deploy (requires GitHub environment approval, main branch only)
        ├── Trigger deployment via Coolify API (hurl)
        ├── Wait for container health check
        └── Run post-deploy verification (test/prod.hurl)
```

A manual verification workflow (`.github/workflows/verify.yml`) can be triggered via
`workflow_dispatch` to re-run production checks without deploying.

### Dependency management (Dependabot)

Automated dependency updates via GitHub Dependabot (`.github/dependabot.yml`):

- **Docker (Dockerfile)**: daily checks for builder/runner base image updates, max 5 open PRs
- **Docker Compose**: daily checks for service image updates
- **Elixir (mix)**: daily checks, max 10 open PRs
- **NPM**: daily checks, max 10 open PRs, ignores path-based local deps
- **GitHub Actions**: daily checks for action version updates

Fluxon (private dependency) is configured with a dedicated registry entry.

### Post-deploy verification

`test/prod.hurl` checks:

- HTTP → HTTPS redirect
- API authentication enforcement
- Valid API responses with auth token
- Dev routes require login
- Bot scanner paths (`wp-admin`, `.env`, `xmlrpc`) return 404

### Deployment credentials

| Secret/Variable    | Purpose                                  |
| ------------------ | ---------------------------------------- |
| `COOLIFY_TOKEN`    | API authentication (GitHub secret)       |
| `COOLIFY_HOST`     | Coolify server address (GitHub variable) |
| `COOLIFY_APP_UUID` | Application identifier (GitHub variable) |

---

## Environment Variables

### Required

| Variable                   | Purpose                                              |
| -------------------------- | ---------------------------------------------------- |
| `DATABASE_PATH`            | Absolute path to main SQLite database                |
| `BACKGROUND_DATABASE_PATH` | Absolute path to background jobs database            |
| `TELEMETRY_DATABASE_PATH`  | Absolute path to telemetry database                  |
| `SECRET_KEY_BASE`          | Phoenix secret (`mix phx.gen.secret`)                |
| `CLOAK_ENCRYPTION_KEY`     | Base64-encoded 32-byte AES key for encrypted secrets |
| `LOGIN_PASSWORD`           | Web login password                                   |
| `API_TOKEN`                | Bearer token for API endpoints                       |
| `MAILGUN_API_KEY`          | Mailgun API key                                      |

### Optional

| Variable                        | Default                   | Purpose                       |
| ------------------------------- | ------------------------- | ----------------------------- |
| `SERVICE_FQDN_WEB`              | `example.com`             | Application domain            |
| `PORT`                          | `4000`                    | HTTP listen port              |
| `POOL_SIZE`                     | `5`                       | Database connection pool size |
| `MAILGUN_DOMAIN`                | `mailgun.fullyforged.com` | Mailgun sending domain        |
| `DEFAULT_TIMEZONE`              | `Europe/London`           | Application timezone          |
| `OPENAI_KEY`                    | —                         | OpenAI API (embeddings, chat) |
| `DISCOGS_PERSONAL_ACCESS_TOKEN` | —                         | Discogs API                   |
| `BRAVE_SEARCH_API_KEY`          | —                         | Brave Search API              |
| `LAST_FM_API_KEY`               | —                         | Last.fm API                   |
| `LAST_FM_SHARED_SECRET`         | —                         | Last.fm scrobbling auth       |
| `LAST_FM_USER`                  | —                         | Last.fm username              |

---

## OTP Release

Standard Mix release. Entry point: `rel/overlays/bin/server` (sets `PHX_SERVER=true`).

Migrations are skipped during release boot (`skip_migrations?/0` returns `true` when
`RELEASE_NAME` is set). Instead, Coolify is configured to run migrations after the
Docker image is built and the container is started — this happens via the
`rel/overlays/bin/migrate` script, executed as a post-deployment command in Coolify
before the application begins serving traffic.

A standalone `rel/overlays/bin/migrate` script is also available for manual use.

ERL_FLAGS: `+JPperf true` (JIT performance monitoring).

---

## Monitoring & Observability

### Health check

`GET /health` — queries the main database, returns 200 or 500. Used by Docker health
checks and post-deploy verification.

### Logging

Production logs are configured for single-line output so every physical log line
corresponds to exactly one log event. This makes log files reliably filterable with
line-oriented tools (grep, tail, sort) and enables deterministic reverse-order reading.

Three layers work together:

1. **Logster v2** — Replaces `Phoenix.Logger` for HTTP request and LiveView socket
   telemetry. Merges `GET + Sent` into a single logfmt line with `method`, `path`,
   `status`, `duration`, and `request_id` fields. Handles `[:phoenix, :socket_connected]`
   telemetry, flattening the multi-line handshake output into one line.

2. **Custom formatter** (`MusicLibrary.Logger.SingleLineFormatter`) — Safety net that
   replaces any remaining embedded newlines (`\n`) with escaped `\\n` in ALL log
   messages. Catches stack traces, Erlang runtime messages, and any multi-line strings
   that Logster does not cover. Configured in `config/prod.exs`.

3. **Config flag** (`single_line_logging`) — Boolean in `config/config.exs` (default
   `false`) and overridden to `true` in `config/prod.exs`. Controls `Logster.attach_phoenix_logger()`
   in `application.ex`. Dev/test environments keep the default multi-line format for readability.

Configuration summary:

```elixir
# config/prod.exs
config :phoenix, :logger, false
config :music_library, :single_line_logging, true

config :logster,
  extra_fields: [:request_id],
  filter_parameters: Application.get_env(:phoenix, :filter_parameters, ["password", "token"])

config :logger, :default_formatter,
  format: {MusicLibrary.Logger.SingleLineFormatter, :format},
  metadata: [:request_id, :pid]
```

Dev environment retains the default `"$time $metadata[$level] $message\n"` format with
`Phoenix.Logger` active.

### Error tracking

`ErrorTracker` with email notifications via Mailgun:

- Listens to `:error_tracker` telemetry events
- Throttles repeated error notifications
- Non-actionable errors (bot scanners, `NoRouteError`) filtered via `ErrorIgnorer`
- Muted errors skip email notifications

### Telemetry

SQLite-backed persistent metrics (`MusicLibraryWeb.Telemetry.Storage`) with 30-second
polling interval. Events are buffered in GenServer state keyed by metric and flushed to
SQLite every 5 seconds inside a single transaction; reads via `metrics_history/1`
force-flush only the requested metric so the dashboard sees fresh data without waiting
for the next tick. Per-metric retention is capped at 32 768 rows
(`:retention_limit`), pruned after each flush. Flush failures are logged at `:warning`
and the offending batch is dropped. Tracks:

- Database query times (total, query, queue)
- External API request latency (Finch)
- Rate limiter throttle durations
- Asset cache hit/miss
- Oban job metrics (enqueue, execute, attempt, discard)
- Scrobble rules processing (duration, exceptions)
- Error tracker counters

### Dashboards (behind auth)

- Phoenix LiveDashboard (`/dev/dashboard`)
- Oban Web (`/dev/oban`)
- ErrorTracker (`/dev/errors`)

### Pi coding agent tools

Pi extensions provide additional tools for production observability without manual SSH
or browser access. Each extension reads its own environment variables from the pi
runtime environment (not server-side config).

| Extension     | Tools                                                                                                         | Env vars                                                     |
| ------------- | ------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| `prod-logs`   | `fetch_production_logs`                                                                                       | `PI_COOLIFY_HOST`, `PI_COOLIFY_APP_UUID`, `PI_COOLIFY_TOKEN` |
| `prod-errors` | `fetch_production_errors`, `fetch_production_error`, `/prod-errors`                                           | `PI_API_TOKEN`, `PI_SERVICE_FQDN_WEB`                        |
| `ci-browser`  | `ci_list_runs`, `ci_view_run`, `ci_find_current_branch_run`, `ci_watch_run`, `ci_watch_current_branch`, `/ci` | `gh` CLI (must be installed and authenticated)               |

**`prod-logs` env vars:**

- `PI_COOLIFY_HOST` — Coolify server base URL (e.g., `https://coolify.example.com`)
- `PI_COOLIFY_APP_UUID` — Application UUID in Coolify
- `PI_COOLIFY_TOKEN` — Coolify API Bearer token

**`prod-errors` tools and command:**

- `fetch_production_errors` — List/filter errors via LLM tool
- `fetch_production_error` — Single error detail via LLM tool
- `/prod-errors` — Interactive TUI for browsing errors (list, detail, filter toggles)

**`prod-errors` env vars:**

- `PI_API_TOKEN` — Must match the `API_TOKEN` env var on the production server (used for Bearer auth on `/api/v1/*`)
- `PI_SERVICE_FQDN_WEB` — Production domain with protocol (e.g., `https://musiclibrary.claudio-ortolina.org`, no trailing slash)

---

## Email

Mailgun via Swoosh (`Swoosh.Adapters.Mailgun`).

| Setting | Value                                |
| ------- | ------------------------------------ |
| From    | `postmaster@mailgun.fullyforged.com` |
| To      | `claudio@fullyforged.com`            |

Used for error notifications and the daily "records on this day" digest email.

---

## Encryption

Cloak vault (`MusicLibrary.Vault`) with AES.GCM cipher for at-rest encryption of
secrets stored in the `secrets` table. Key configured via `CLOAK_ENCRYPTION_KEY`
(base64-encoded 32-byte key).

---

## Tool Versions

Defined in `mise.toml`.
