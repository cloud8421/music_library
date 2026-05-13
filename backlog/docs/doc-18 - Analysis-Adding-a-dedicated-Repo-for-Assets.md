---
id: doc-18
title: "Analysis: Adding a Dedicated Repo for Assets"
type: specification
created_date: "2026-05-13 14:57"
updated_date: "2026-05-13 15:14"
tags:
  - architecture
  - database
  - assets
  - evaluation
---

# Analysis: Adding a Dedicated Repo for Assets

> **Date**: 2026-05-13
> **Status**: proposal evaluation

---

## Executive Summary

Adding a dedicated `MusicLibrary.AssetsRepo` and migrating the `assets` table out of `MusicLibrary.Repo` into a separate SQLite database would require significant, high-risk changes across the entire stack — from database queries to backups to deployments. The benefits are marginal for a personal music library application. **The recommendation is to NOT proceed.**

---

## Current State

The `assets` table lives in the **main `MusicLibrary.Repo`** database alongside all other application schemas (records, artist_infos, notes, chats, record_sets, scrobble_rules, secrets, online_store_templates, record_embeddings, FTS5 search index, record_releases view, artist_records view).

### Assets design

| Property        | Detail                                                                              |
| --------------- | ----------------------------------------------------------------------------------- |
| Primary key     | `hash` (SHA256, string) — content-addressable, immutable                            |
| Columns         | `content` (binary), `format` (string), `properties` (map), timestamps               |
| Insert strategy | `on_conflict: :nothing` — idempotent, no duplicates                                 |
| Read path       | `Assets.get(hash)` → DB lookup, fronted by 7-day ETS cache                          |
| Write path      | `Assets.store_image/1` → hash computed from content, inserted                       |
| Cleanup         | `Assets.prune_unreferenced/0` → LEFT JOIN on records + artist_infos, delete orphans |

### References from other tables (all plain string fields, no FK constraints)

| Table                  | Column            | Notes                                           |
| ---------------------- | ----------------- | ----------------------------------------------- |
| `records`              | `cover_hash`      | Main record cover art reference                 |
| `records_search_index` | `cover_hash`      | FTS5 virtual table, auto-synced via DB triggers |
| `record_releases`      | `cover_hash`      | SQL view (read-only, no PK)                     |
| `artist_infos`         | `image_data_hash` | Artist image reference                          |

### Current repo configuration

```
ecto_repos: [MusicLibrary.BackgroundRepo, MusicLibrary.Repo, MusicLibrary.TelemetryRepo]
```

| Repo             | DB file                                | Cache size | Pool size | Extensions    |
| ---------------- | -------------------------------------- | ---------- | --------- | ------------- |
| `Repo`           | `data/music_library_dev.db`            | 128 MB     | 5 (prod)  | unicode, vec0 |
| `BackgroundRepo` | `data/music_library_background_dev.db` | 16 MB      | 5 (prod)  | —             |
| `TelemetryRepo`  | `data/music_library_telemetry_dev.db`  | 4 MB       | 2         | —             |

---

## What Would Need to Change

### 1. Code Changes (high blast radius)

#### New Repo module

```elixir
# New: lib/music_library/assets_repo.ex
defmodule MusicLibrary.AssetsRepo do
  use Ecto.Repo, otp_app: :music_library, adapter: Ecto.Adapters.SQLite3
end
```

#### Supervision tree

Add `MusicLibrary.AssetsRepo` to the children list in `MusicLibrary.Application`.

#### Assets context — every function changes Repo

Every `Repo.insert/2`, `Repo.get/2`, `Repo.get!/2`, `Repo.one/2`, `Repo.delete_all/2` in `lib/music_library/assets.ex` must be changed to use `AssetsRepo` instead of `Repo`.

```diff
- alias MusicLibrary.Repo
+ alias MusicLibrary.AssetsRepo
```

This is mechanical but pervasive — currently 6 Repo calls in `assets.ex`.

#### Assets.prune_unreferenced/0 — BROKEN by separation

This function performs a LEFT JOIN across `assets`, `records`, and `artist_infos` to find unreferenced assets:

```elixir
from a in Asset,
  left_join: r in MusicLibrary.Records.Record, on: r.cover_hash == a.hash,
  left_join: ai in MusicLibrary.Artists.ArtistInfo, on: ai.image_data_hash == a.hash,
  where: is_nil(r.id) and is_nil(ai.id),
  select: a.hash
```

**SQLite does not support JOINs across separate database files.** This would need to be rewritten as:

1. Fetch all asset hashes from AssetsRepo
2. Fetch all cover_hashes from Repo (records)
3. Fetch all image_data_hashes from Repo (artist_infos)
4. Compute difference in Elixir
5. Delete from AssetsRepo

This is O(n) in asset count, cannot use SQL indexes for the join, and would require loading potentially thousands of hashes into memory.

#### Cross-repo asset lookups

Every place that loads a record and then fetches its cover asset (indirectly via `AssetController`) stays the same — the controller already calls `Assets.get(hash)` which would switch repos. No change needed at the controller level.

However, any future code that needs transactional consistency between asset writes and record writes would be impossible (no cross-database transactions in SQLite).

#### Asset references — no FK enforcement possible

`records.cover_hash` and `artist_infos.image_data_hash` are plain string columns. They cannot be foreign keys because they point to a different database. This is already the case (they're not FKs now either) but would become a permanent architectural constraint.

### 2. Configuration Changes

#### `config/config.exs`

```diff
config :music_library,
-  ecto_repos: [MusicLibrary.BackgroundRepo, MusicLibrary.Repo, MusicLibrary.TelemetryRepo],
+  ecto_repos: [..., MusicLibrary.AssetsRepo],
```

#### `config/runtime.exs` (prod only)

New database path env var, new repo config block:

```elixir
config :music_library, MusicLibrary.AssetsRepo,
  database: System.get_env("ASSETS_DATABASE_PATH"),
  auto_vacuum: :incremental,
  cache_size: -64_000,
  pool_size: String.to_integer(System.get_env("ASSETS_POOL_SIZE") || "3"),
  show_sensitive_data_on_connection_error: false
```

This adds one new **required** env var (`ASSETS_DATABASE_PATH`) and one optional (`ASSETS_POOL_SIZE`).

### 3. Migration Infrastructure

#### Migrations for the new repo

Ecto migrations are configured per-repo via `priv/` directory. Currently:

- `MusicLibrary.Repo` → `priv/repo/migrations/`
- `MusicLibrary.BackgroundRepo` → `priv/background_repo/`
- `MusicLibrary.TelemetryRepo` → `priv/telemetry_repo/`

A new repo needs its own migration directory (e.g., `priv/assets_repo/migrations/`). The existing `create_assets` migration would need to be copied there, and a new cleanup migration would need to remove the table from the main DB.

```elixir
config :music_library, MusicLibrary.AssetsRepo, priv: "priv/assets_repo"
```

#### `MusicLibrary.Release.migrate/0`

`rel/overlays/bin/migrate` currently runs migrations for all repos. Would automatically pick up the new repo since `ecto_repos` is enumerated. No changes needed — this is one of the few safe parts.

### 4. Production Infrastructure Changes

#### Database files

| Change          | Impact                                                       |
| --------------- | ------------------------------------------------------------ |
| New DB file     | `/mnt/music_library/music_library_assets_prod.db` or similar |
| New env var     | `ASSETS_DATABASE_PATH` (required)                            |
| New env var     | `ASSETS_POOL_SIZE` (optional)                                |
| Main DB shrinks | Assets binary data removed from main DB                      |

#### Volume mounts

`compose.yaml` already mounts `/data/coolify/applications/music-library:/mnt/music_library`. All DB files live under this directory, so a new file is automatically accessible. No volume mount change needed.

#### Litestream backup (CRITICAL)

`compose.yaml` hardcodes the Litestream config with a single database path:

```yaml
dbs:
  - path: /mnt/music_library/music_library_prod.db
    replica:
      type: s3
      ...
```

A second `dbs` entry must be added for the assets DB. This doubles the Litestream sync workload and S3 storage. For a personal collection, this is negligible, but it adds operational complexity.

#### Manual backup tasks

`mise run prod:backup` uses `sqlite3 .backup` — would need to also back up the assets DB, or be updated to use `sqlite3 .backup` for each database. `mise run prod:litestream-backup` would restore both.

#### Coolify deployment

- New env var must be added to the Coolify service configuration
- `rel/overlays/bin/migrate` is already called by Coolify and runs for all repos — no change needed
- Dockerfile — no change needed (Elixir release bundles all code)

#### Health check

`HealthController` queries `MusicLibrary.Repo` with `SELECT 1`. Does not check assets DB health. Could add a second check, or leave as-is (assets DB downtime is less critical since the ETS cache absorbs reads).

### 5. Performance Analysis

#### Current performance

- Asset reads: `Assets.get(hash)` → 1 SQLite query, ~0.1ms for indexed hash lookup
- Fronted by ETS cache (7-day TTL) → most requests never hit the DB
- Asset writes: `Repo.insert(on_conflict: :nothing)` → 1 SQLite write, idempotent
- Pruning: LEFT JOIN across 3 tables in a single query
- All within a single connection pool (5 connections in prod)

#### After separation

- Asset reads: **no change** for cache hits. Cache misses: 1 query to AssetsRepo, still ~0.1ms
- Asset writes: **no change** (still 1 insert, different pool)
- Pruning: **significantly worse** — would need to load all hashes from both databases into Elixir memory, compute set difference, then batch-delete. Currently handled in a single SQL query.
- Connection pool overhead: additional pool (3 connections) = slightly more memory (each SQLite connection holds a ~cache_size page cache in memory). At 64MB cache, 3 connections = ~192MB RSS overhead for the assets pool.

#### Memory impact

| Component       | Current            | After            | Delta      |
| --------------- | ------------------ | ---------------- | ---------- |
| Main DB cache   | 5 × 32MB = 160MB\* | 5 × 32MB = 160MB | 0          |
| Assets DB cache | 0                  | 3 × 64MB = 192MB | +192MB     |
| **Total**       | **160MB**          | **352MB**        | **+192MB** |

\*(pool_size × cache_size/pool_size; SQLite divides cache among connections)

The actual memory freed from the main DB by removing assets is hard to predict — SQLite cache pages are shared across connections via shared cache mode in WAL, so removing asset data from the main DB would reduce its working set, but the per-connection cache allocation doesn't automatically shrink.

#### Disk impact

Asset binary data moves from main DB to assets DB. The main DB file size decreases but the total disk usage stays approximately the same (plus a small amount of per-DB overhead). SQLite WAL files and SHM files now exist for 4 databases instead of 3.

### 6. Transactional Consistency

Currently, when a record is created with a cover image:

```elixir
{:ok, asset} <- Assets.store_image(...)       # Repo.insert
record = build_record_attrs(..., %{cover_hash: asset.hash})
Records.create_record(record)                   # Repo.insert
```

These are **two separate transactions** today (not wrapped in `Repo.transaction`). So separation doesn't break any existing transactional guarantees — they were already absent.

However, it permanently precludes adding transactional consistency in the future. If you ever wanted to atomically insert an asset + record (roll back the asset if the record insert fails), that's impossible across databases.

### 7. Development Experience

#### Setup complexity

- New mix task or manual step to create/migrate the assets DB
- `.mise/tasks` would need a new entry for assets DB setup
- Test helpers would need to handle 4 repos instead of 3

#### Testing

Tests currently use `MusicLibrary.Repo` sandbox mode. Another repo means another sandbox configuration. Test setup already handles `BackgroundRepo` separately (Oban testing), so adding a 4th is incremental pain, not a step change.

#### CI

- GitHub Actions workflow would need `ASSETS_DATABASE_PATH` env var (set to a temp path like the others)
- Test partitioning would need to account for the new repo

### 8. Migration Path (if proceeding)

If the decision is made to proceed, the migration must be:

1. **Create new AssetsRepo** — module, config, supervision
2. **Dual-write phase** — write to both old and new assets tables
3. **Backfill** — copy all existing asset rows from old DB to new DB via Elixir script
4. **Switch reads** — point all `Assets.*` functions to AssetsRepo
5. **Verify** — compare row counts, hash integrity
6. **Drop old table** — migration to drop assets table from main DB
7. **Update prune logic** — rewrite without cross-DB JOIN

This is a multi-step deployment requiring at least 2 releases. Any error during the dual-write or backfill phases could result in data loss (asset binary content not copied).

---

## Pros

1. **Concern separation** — Assets are a distinct concern (binary storage), separate from relational application data
2. **Independent scaling** — Pool size, cache size, vacuum schedule can be tuned for assets specifically
3. **Smaller main DB** — Removing binary blobs from the main DB reduces its file size, making vacuum/backup faster
4. **Cleaner backup granularity** — Could back up assets less frequently than the main DB (assets are immutable and derivable from original sources)

## Cons

1. **Cross-database JOINs are impossible** — SQLite has no cross-file query support. `prune_unreferenced/0` must be rewritten as application-level logic
2. **Permanent loss of transactional consistency** — Cannot atomically create an asset and reference it from a record
3. **Operational complexity** — +1 env var, +1 DB file, +1 Litestream backup, +1 pool, +1 migration directory
4. **Memory overhead** — +192MB RSS for the additional connection pool with its cache
5. **Risky migration** — Moving binary data between databases requires careful dual-write/backfill/cutover with data loss risk
6. **Minimal practical benefit** — Assets are already content-addressable and cache-fronted. The ETS cache absorbs reads. The existing design is clean and working
7. **Brittle future refactors** — Any new feature that joins assets with another table must implement application-level joins
8. **Pruning becomes expensive** — Current O(1) SQL query becomes O(n) Elixir computation loading all hash sets into memory

## Verdict

**Do not proceed.** The costs far outweigh the benefits for this application's scale and context. The current architecture — assets co-located with the data that references them — is the correct design for a single-node SQLite application.

The only scenario where this would make sense is if:

- Asset storage was moved to a completely different backend (S3, dedicated file server)
- The application needed to scale asset serving independently from the main DB
- Multiple applications needed to share the same asset store

None of these apply to a personal music library running as a single Docker container on a single host.

## Alternatives Worth Considering

If the goal is to reduce database bloat or improve performance, consider these instead:

| Alternative                                  | Effort                      | Benefit                                                                                                                                                                                            |
| -------------------------------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Increase ETS cache TTL** (14 or 30 days)   | Trivial (1 constant change) | Fewer DB reads without any structural change                                                                                                                                                       |
| **Store assets on filesystem** instead of DB | Medium                      | DB stays small, filesystem is purpose-built for serving binary data. AssetController reads from disk. Litestream no longer backs up assets (they're derivable from MusicBrainz/Cover Art Archive). |
| **Pre-resize and store multiple sizes**      | Medium                      | Eliminates CPU cost of `Image.resize` on every cache miss. Store thumbnails at common widths (40, 96, 150, 480, 2000) at insert time.                                                              |
| **Lazy-load asset content**                  | Low-Medium                  | Keep the `assets` table but make `content` a separate query or decompress on read. Marginal benefit.                                                                                               |

---

## Follow-up Analysis: Measured Footprint and Operational Blast Radius

> **Date**: 2026-05-13
> **Basis**: code trace plus local development database measurements

### Measured local database footprint

The local development database confirms that this is operationally meaningful, even if not primarily a request-latency optimization.

| Metric                           | Value             |
| -------------------------------- | ----------------- |
| Asset rows                       | 1,539             |
| Asset content bytes              | 558,387,015 bytes |
| Asset table pages from `dbstat`  | 561,946,624 bytes |
| Main DB `dbstat` total           | 789,073,920 bytes |
| Asset share of main DB footprint | 71.2%             |
| Main DB file size on disk        | ~753 MB           |
| Distinct record cover hashes     | 1,151             |
| Distinct artist image hashes     | 388               |
| Currently unreferenced assets    | 0                 |

This means moving assets out would materially shrink the hot application DB after the old table is dropped and the main DB is vacuumed. It would not materially reduce total disk usage; it mostly redistributes bytes into another SQLite file.

### Current behavior that matters

The current asset API surface is intentionally small:

- `MusicLibrary.Assets.store/1`
- `MusicLibrary.Assets.store_image/1`
- `MusicLibrary.Assets.get/1`
- `MusicLibrary.Assets.get!/1`
- `MusicLibrary.Assets.total_content_size/0`
- `MusicLibrary.Assets.prune_unreferenced/0`

Most callers can remain behind this context boundary if an `AssetsRepo` is added. The broadest code change is not call-site churn; it is operational behavior around migrations, backups, restore, health checks, telemetry, tests, and pruning.

The request path is already favorable:

1. `AssetController` checks the ETS transform cache.
2. Cache miss reads the original asset by primary-key hash.
3. The image is resized or converted via Vix.
4. The transformed result is cached in ETS and returned with long-lived HTTP cache headers.

So expected user-facing performance gains are modest. Cache misses still need a primary-key lookup and image processing; cache hits do not touch the DB either way.

### Important pruning nuance

The earlier section says SQLite does not support cross-file joins. More precisely: normal Ecto joins across two separate Repo modules do not work. SQLite can technically use `ATTACH DATABASE` and join attached databases on a single connection, but that would be raw SQL, connection-scoped, and awkward inside a separate Ecto Repo design.

Practical pruning options after separation would be:

| Option                                       | Assessment                                                                                                                                          |
| -------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- |
| App-level set comparison                     | Simple and acceptable at current scale; fetch asset hashes and referenced hashes, compute difference in Elixir, batch-delete from `AssetsRepo`.     |
| Temp referenced-hashes table in `AssetsRepo` | More scalable; copy current references into a temporary table and delete with SQL. More code and migration/test complexity.                         |
| Raw SQLite `ATTACH` maintenance query        | Possible, but brittle with Ecto pool ownership and connection scope. Best treated as a maintenance-only escape hatch, not a normal context pattern. |

At current scale, app-level set comparison is not a serious memory risk. The risk is architectural: future code must remember that asset references cannot be joined through regular Ecto queries.

### Production blast radius

The production setup currently assumes one main application DB plus background and telemetry DBs. Moving assets adds a fourth database with its own lifecycle.

Affected production surfaces:

| Surface                | Current assumption                                                     | Required change                                                                                |
| ---------------------- | ---------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Runtime config         | `DATABASE_PATH`, `BACKGROUND_DATABASE_PATH`, `TELEMETRY_DATABASE_PATH` | Add required `ASSETS_DATABASE_PATH`; optionally `ASSETS_POOL_SIZE`.                            |
| Supervision            | Starts `Repo`, `BackgroundRepo`, `TelemetryRepo`                       | Start `AssetsRepo` before endpoint and before any asset-serving path.                          |
| Release migrations     | Iterates `:ecto_repos`                                                 | Add `AssetsRepo` to `:ecto_repos` and set `priv: "priv/assets_repo"`.                          |
| Litestream             | Replicates only `/mnt/music_library/music_library_prod.db`             | Add a second `dbs` entry for the assets DB.                                                    |
| Manual backup          | `scripts/prod/backup` backs up only `music_library_prod.db`            | Back up both main and asset DBs, ideally with close timestamps and restore instructions.       |
| Litestream restore     | `scripts/prod/litestream-backup` restores only the main DB             | Restore both replicas.                                                                         |
| `/backup` endpoint     | Sends only `MusicLibrary.Repo` database file                           | Decide whether to return a bundle or expose separate downloads.                                |
| Health check           | `SELECT 1` only against `MusicLibrary.Repo`                            | Add asset DB check if missing images should fail health, or keep main-only by design.          |
| Production Hurl checks | API latest record and cover fetch                                      | Cover fetch should continue to catch broken asset serving, but not backup/restore consistency. |
| LiveDashboard          | Lists three repos                                                      | Add `AssetsRepo` to dashboard repo list.                                                       |
| Docs                   | Three database architecture                                            | Update architecture and production infrastructure docs if implemented.                         |

Backup and restore consistency is the biggest operational risk. Assets are immutable and content-addressed, which helps, but a point-in-time restore can still produce a main DB that references hashes missing from the restored asset DB if the two replicas are restored to different moments.

Mitigations if proceeding:

- Restore the asset DB to the same timestamp or slightly after the main DB timestamp.
- Add a verification task that checks every `records.cover_hash` and `artist_infos.image_data_hash` exists in `AssetsRepo`.
- Keep old assets in the asset DB even when unreferenced until after backup retention makes rollback safe.
- Avoid destructive pruning during or immediately after migration cutover.

### Performance implications

Benefits:

- Main DB file and working set shrink substantially once old asset rows are removed and vacuumed.
- Large binary writes no longer share the main Repo's write path.
- Asset pool/cache tuning can be independent from relational data.
- Main DB backup, download, vacuum, and optimize operations become lighter.

Costs:

- Total disk usage is roughly unchanged and may increase slightly due per-database overhead, WAL, and SHM files.
- Another SQLite pool adds memory overhead. The exact cost depends on `cache_size` and pool size.
- Transform cache misses still pay image processing cost, so request latency improvement is unlikely to be dramatic.
- Pruning moves from a single SQL join to either application-level comparison or more specialized raw SQL.
- Telemetry and debugging need to distinguish main Repo query time from asset Repo query time.

A low-risk performance alternative is to keep the table in the main DB but add explicit indexes on `records.cover_hash` and `artist_infos.image_data_hash` if pruning ever becomes slow. SQLite currently plans automatic covering indexes for the prune query, but explicit indexes would make that deterministic.

### Refined recommendation

A dedicated `AssetsRepo` is feasible and has a real operational upside: it would remove roughly 70% of the current main DB footprint from the relational database file. That is meaningful for backups, vacuuming, local restore size, and keeping the primary application DB focused on relational data.

It should not be justified as an image-serving speedup. The existing ETS cache and primary-key hash reads already make the runtime request path efficient. If the goal is faster image serving, optimize transform caching, precomputed sizes, or storage format first.

Proceed only if the goal is explicitly operational isolation and main DB size reduction. If implemented, use a phased rollout:

1. Add `AssetsRepo`, config, migrations, supervision, test sandbox setup, dashboard visibility, and health/backup decisions.
2. Introduce read fallback from the old main `assets` table to the new asset DB.
3. Backfill assets idempotently and verify row count, byte count, hash integrity, and all current references.
4. Switch writes to the new repo, preferably with temporary dual-write for rollback safety.
5. Update Litestream, manual backup, restore, `/backup`, docs, and production verification.
6. After a stable retention window, remove fallback/dual-write, drop the old main `assets` table, and run `VACUUM`.

The safest final position remains: do not make this change unless the operational value of shrinking the main DB is worth the added backup and restore complexity.
