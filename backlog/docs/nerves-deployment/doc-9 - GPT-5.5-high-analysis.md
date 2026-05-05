---
id: doc-9
title: "GPT 5.5, high analysis"
type: other
created_date: "2026-05-04 15:11"
---

# Nerves Deployment Research Report

Date: 2026-05-04

## Scope

This report explores the feasibility and risk areas for deploying this Phoenix/SQLite music library application as part of a Nerves application. No implementation work was performed.

The research focused on:

- Native dependencies and NIF availability for ARM/Nerves targets.
- SQLite loadable extensions on Linux ARM.
- Litestream replication behavior, especially conflicts and local writes.
- Project-specific architecture implications based on the current application docs and dependency graph.

## Project Context

The application is a Phoenix LiveView app backed by three SQLite databases:

- `MusicLibrary.Repo`: main application data.
- `MusicLibrary.BackgroundRepo`: Oban jobs.
- `MusicLibrary.TelemetryRepo`: persistent telemetry metrics.

The main repo loads two SQLite extensions at runtime:

- `unicode`
- `vec0`

The application currently ships precompiled extension binaries for:

- `darwin-amd64`
- `darwin-arm64`
- `linux-amd64`
- `linux-arm64`

The app also uses several native or precompiled-native dependencies:

- `exqlite`, via `ecto_sqlite3`
- `vix`, backed by libvips
- `dominant_colors`, via RustlerPrecompiled
- `mdex`, via RustlerPrecompiled
- `lumis`, via RustlerPrecompiled
- `typst`, via RustlerPrecompiled

## Summary

A Nerves deployment appears feasible as a read-only or mostly read-only edge deployment, but it should not be treated as a second writable production node.

The central architectural constraint is that Litestream is not an application-level sync or conflict-resolution system. It is physical SQLite/WAL replication. If the Nerves device writes to its local database, those writes either remain local, conflict with read-replica/follow mode, or create a divergent database history.

The safest complementary architecture is:

1. The Nerves device keeps a local read model restored from production.
2. User writes are sent to the production app through an authenticated API.
3. Production remains the single SQLite writer.
4. Litestream brings the resulting production state back down to the device.
5. Offline-capable writes, if required, are handled with an application-level outbox and explicit conflict rules.

## Native Dependency Challenges

### Nerves Cross-Compilation Model

Nerves sets environment variables that are intended to support cross-compiling C/C++ NIFs and ports, including `CC`, `CFLAGS`, `LDFLAGS`, `CROSSCOMPILE`, `NERVES_SDK_SYSROOT`, `TARGET_ARCH`, `TARGET_OS`, and `TARGET_ABI`.

This is helpful for dependencies that use standard `elixir_make`, `cc_precompiler`, Rustler, or RustlerPrecompiled flows. It does not guarantee that every dependency will compile cleanly, especially if the dependency needs system libraries that are not present in the Nerves system.

Source: https://hexdocs.pm/nerves/environment-variables.html

### Exqlite / Ecto SQLite

`ecto_sqlite3` depends on `exqlite`. Exqlite documents precompiled artifacts and native build options. It can also be forced to use a system SQLite through `EXQLITE_USE_SYSTEM`, `EXQLITE_SYSTEM_CFLAGS`, and `EXQLITE_SYSTEM_LDFLAGS`.

Risk level: medium.

Likely challenge:

- Verifying that the selected Nerves target receives a compatible Exqlite NIF.
- Deciding whether to use bundled SQLite or a system SQLite from the Nerves image.
- Ensuring SQLite compile-time options still satisfy app requirements, especially FTS5 and loadable extensions.

Source: https://hexdocs.pm/exqlite/readme.html

### Vix / Libvips

`vix` is the highest-risk native dependency in this application.

Vix includes prebuilt binaries for macOS and Linux, and it can alternatively use a platform-provided libvips by setting:

```sh
VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS
```

However, on Nerves this may require a custom Nerves system that includes libvips and its development headers. Vix also has historically been tricky in cross-compilation contexts because it depends on libvips introspection during compilation.

Risk level: high.

Likely challenge:

- Official Nerves systems may not include libvips.
- A custom Buildroot/Nerves system may be needed.
- Optional libvips codec support may differ from production.
- Image processing behavior may not match production unless libvips versions and build options are controlled.

Sources:

- https://hexdocs.pm/vix/readme.html
- https://hexdocs.pm/nerves/customizing-systems.html
- https://elixirforum.com/t/cross-compiling-with-nif-as-compilation-dependency/59821

### RustlerPrecompiled Dependencies

RustlerPrecompiled supports Nerves-style target detection via `TARGET_ARCH`, `TARGET_ABI`, and `TARGET_OS`. Default targets include common ARM Linux triples such as:

- `aarch64-unknown-linux-gnu`
- `aarch64-unknown-linux-musl`
- `arm-unknown-linux-gnueabihf`

This is promising for `mdex`, `lumis`, `typst`, and `dominant_colors`, but every package still needs to publish compatible precompiled artifacts for the relevant target and NIF version.

Risk level: medium.

Specific concern:

- `dominant_colors` is old and low-activity. It depends on `rustler_precompiled ~> 0.7`, and there is no guarantee that all current Nerves targets are covered.

Sources:

- https://hexdocs.pm/rustler_precompiled/RustlerPrecompiled.html
- https://hex.pm/packages/dominant_colors

## SQLite Extension Challenges

The app already includes `priv/sqlite_extensions/linux-arm64/unicode.so` and `vec0.so`. This is a good starting point, but it does not prove Nerves compatibility.

Open questions:

- Were the `linux-arm64` extensions built against assumptions compatible with the target Nerves system?
- Are they dynamically linked against glibc or musl expectations that differ from the Nerves target?
- Do they require symbols unavailable in the SQLite build used by Exqlite?
- Does the target allow SQLite loadable extensions as used by Ecto/Exqlite?

The current platform detection only maps Linux `aarch64` to `linux-arm64`. That means 32-bit ARM targets such as Raspberry Pi Zero-class systems would fail unless new binaries and platform mapping were added.

Risk level: medium for aarch64, high for arm32.

Recommended spike:

- Build a minimal Nerves firmware for the intended target.
- Boot it on hardware or QEMU if possible.
- Run only the repo extension tests:
  - `SELECT vec_version()`
  - Unicode extension behavior currently covered by `test/music_library/repo_test.exs`

## Nerves Filesystem and Runtime Considerations

Nerves root filesystems are read-only by default. Persistent data should live on the writable data partition, typically `/data`.

This affects:

- `DATABASE_PATH`
- `BACKGROUND_DATABASE_PATH`
- `TELEMETRY_DATABASE_PATH`
- Litestream restore target paths
- Litestream buffers, if using VFS write mode
- Temporary files used by image/PDF processing

Source: https://hexdocs.pm/nerves/faq.html

The current application expects runtime environment variables for production configuration. A Nerves deployment would need a target-specific runtime configuration story for:

- `SECRET_KEY_BASE`
- `CLOAK_ENCRYPTION_KEY`
- `LOGIN_PASSWORD`
- `API_TOKEN`
- External API keys, if those features are enabled
- SQLite DB paths under `/data`

## Litestream Findings

### What Litestream Does

Litestream is a streaming replication and disaster recovery tool for SQLite. It runs as a separate process and continuously copies WAL data to a replica store such as S3-compatible object storage.

It is physical replication, not row-level sync.

Source: https://litestream.io/how-it-works/

### Restore Mode

`litestream restore` can restore a database from a replica. It can also restore to a specific transaction ID or timestamp.

`restore -f` enables follow mode, continuously applying new data as it becomes available. Litestream explicitly states that the restored database in follow mode should only be opened read-only.

Source: https://litestream.io/reference/restore/

Implication:

- Follow mode is a good fit for a local read replica.
- It is not a fit for local writes.

### VFS Read Replica

The Litestream VFS can serve reads directly from object storage. It is read-only by default, fetches pages on demand, caches them, and polls for new LTX files.

Important constraints:

- Write attempts fail unless write mode is enabled.
- It requires a CGO-enabled SQLite VFS extension.
- It is network-latency sensitive.
- It needs contiguous LTX coverage.
- Initial snapshot availability is required.

Source: https://litestream.io/reference/vfs/

Implication for Nerves:

- The VFS is probably more complex than a restore-to-`/data` approach.
- Building and loading `litestream-vfs` on Nerves would be a separate native extension challenge.
- A fully restored local DB is likely simpler and more robust for embedded use.

### VFS Write Mode

Litestream VFS write mode allows writes to a remote-first database by buffering local changes and periodically uploading them.

However, Litestream documents that write mode assumes a single writer. Multiple writers trigger conflict detection, not conflict prevention or automatic conflict resolution.

Limitations include:

- Single-writer assumption.
- Sync latency.
- Local write buffer disk usage.
- Crash window for unsynced buffered writes.
- Application-owned conflict resolution.

Source: https://litestream.io/guides/vfs-write-mode/

Implication:

- VFS write mode should not be used to let production and a Nerves device both write to the same logical database unless an external single-writer lock exists.
- It does not solve offline bidirectional sync.

## What Happens If the Device Writes?

There are several possible scenarios.

### Scenario 1: Device Restores Production DB Once and Writes Locally

The device diverges from production.

Production does not receive those writes. Later restores or updates from production may overwrite or invalidate the local changes depending on the restore strategy.

There is no automatic merge.

### Scenario 2: Device Uses `restore -f` and Also Writes

This is unsupported. Litestream says follow-mode restored databases should only be opened read-only.

Expected outcome:

- Conflict or corruption risk.
- Follow mode may be unable to apply incoming production changes cleanly.

### Scenario 3: Device Uses Litestream VFS Read Replica and Writes

By default, writes fail because the VFS is read-only.

### Scenario 4: Device Uses VFS Write Mode Against Same Replica Path as Production

This is a multiple-writer design. Litestream detects conflicts but does not reconcile them.

Expected outcome:

- Conflict errors.
- Need for application retry/rebase logic.
- Possible divergent generations or failed sync depending on exact mode.

### Scenario 5: Device Sends Writes to Production API

This is the cleanest model.

Production remains the only writer to the production SQLite database. The device reads a replicated copy and submits commands to production when it needs to mutate state.

This works well when the device has network connectivity.

### Scenario 6: Device Supports Offline Writes

This requires application-level sync.

A likely shape:

- Device stores local commands/events in a separate outbox database.
- Each command has an idempotency key.
- The production API accepts commands and performs validation/conflict checks.
- Production returns accepted/rejected/conflicted status.
- Device periodically pushes pending commands.
- Device refreshes its read model from Litestream.

This is not something Litestream provides.

## Data Architecture Recommendations

### Recommended Baseline: Read Replica + Write-Through API

Use Litestream to hydrate the main application database onto the device under `/data`.

Only replicate the main app DB:

- Replicate `MusicLibrary.Repo`: yes.
- Replicate `MusicLibrary.BackgroundRepo`: probably no.
- Replicate `MusicLibrary.TelemetryRepo`: no.

Make the local app behave as read-only for production-backed tables, or route mutations through the production API.

Benefits:

- Avoids multi-writer SQLite.
- Avoids Litestream conflict semantics.
- Keeps production as source of truth.
- Preserves the current production deployment model.

Challenges:

- The UI may currently assume writes are local Ecto writes.
- Many LiveView workflows may need capability checks.
- Oban workers on device must be carefully disabled or narrowed.

### Alternative: Device-Local Features Only

Allow writes only to separate device-local tables/databases:

- Device settings.
- Local telemetry.
- Local cache state.
- Sync metadata.
- Offline outbox.

Keep production-replicated data read-only.

This avoids mixing local-only rows into the production physical database copy.

### Avoid: Bidirectional Litestream

Do not attempt to use Litestream as a bidirectional sync system between production and Nerves.

The core problem is that Litestream replicates database pages/WAL, not business operations. It has no understanding of records, notes, assets, chats, Oban jobs, timestamps, or conflict intent.

## Application-Specific Concerns

### Oban

The app uses Oban heavily for imports, enrichments, external API calls, periodic refreshes, and maintenance.

On a device:

- Running production Oban jobs locally would be risky.
- Replicating the Oban database would be risky.
- Cron jobs that mutate the main database should likely be disabled.
- External API workers may be inappropriate if API secrets are not present.

The Nerves deployment probably needs a distinct Oban configuration:

- disabled entirely, or
- local-only queues, or
- only maintenance tasks that do not mutate production-backed data.

### Secrets

The main DB contains encrypted secrets via Cloak. If production data is restored to the device, encrypted rows come with it.

Options:

- Put the same `CLOAK_ENCRYPTION_KEY` on the device, which increases exposure risk.
- Do not replicate secrets.
- Keep replicated DB encrypted-but-unreadable for those features.
- Split secrets into a production-only database/table in a future architecture.

### Assets

Assets are stored as binary blobs in SQLite and content-addressed by hash. This is favorable for replication because immutable content has simpler conflict semantics.

However:

- Large assets affect restore time and storage wear.
- Cover refresh/image generation on-device may exercise Vix/libvips.

### Embeddings and sqlite-vec

The app uses OpenAI embeddings and `sqlite-vec`.

Read-only similarity search on the device should be plausible if `vec0` loads. Generating embeddings on-device would require OpenAI credentials and write access, so it should probably stay production-side.

### External APIs

MusicBrainz, Last.fm, Discogs, Wikipedia, Brave Search, OpenAI, and Mailgun are integrated.

On-device deployment should decide which of these are:

- disabled,
- proxied through production,
- allowed directly from the device.

For most production-backed data mutations, proxying through production is cleaner.

## Proposed Research Spikes

### Spike 1: Minimal Nerves Build

Goal:

- Determine whether the current dependency tree can build for the intended Nerves target.

Checks:

- `exqlite` NIF loads.
- RustlerPrecompiled dependencies load.
- Vix loads or fails with a clear path.
- Firmware size remains acceptable.

### Spike 2: SQLite Extension Load Test

Goal:

- Verify `unicode.so` and `vec0.so` on target hardware.

Checks:

- `MusicLibrary.Repo.ensure_supported_platform!()`
- `SELECT vec_version()`
- representative FTS/unicode behavior
- vector similarity query

### Spike 3: Read-Only Litestream Replica

Goal:

- Restore the production main DB to `/data`.
- Start app with the main repo opened read-only if possible.
- Confirm browsing/search/similarity workflows.

Checks:

- cold restore time
- incremental update lag
- disk usage
- behavior during network loss
- behavior during power loss

### Spike 4: Write-Through Prototype

Goal:

- Pick one simple mutation, such as creating a note or updating wishlist state.
- Route it to production API instead of local DB.
- Observe how the replicated DB catches up.

Checks:

- UX during replication lag
- idempotency
- authentication
- error handling

### Spike 5: Offline Outbox Design

Goal:

- Only if offline writes are a requirement.
- Design command schema, conflict policy, and reconciliation flow.

Likely requirements:

- globally unique command IDs
- entity version or `updated_at` checks
- tombstones for deletes
- conflict UI or deterministic server-side policy
- separation between read model DB and local outbox DB

## Open Questions

- Which hardware target is intended: Raspberry Pi 4/5 aarch64, Raspberry Pi Zero arm32, or something else?
- Does the device need to serve the full LiveView UI, or a constrained local UI?
- Is the device expected to work without internet?
- Are local writes required, or can all writes go through production?
- Should sensitive tables such as `secrets`, `chats`, and possibly API-derived metadata be present on the device?
- Is Vix/libvips actually needed on the device, or can image processing be production-only?
- Should the device run any Oban workers?
- Is the production S3-compatible bucket reachable from the device network?
- Is eventual consistency acceptable for the UI after write-through actions?

## Conclusion

The Nerves architecture is plausible if the device is treated as an edge read replica with carefully selected local behavior. The native dependency work is significant but bounded: Vix/libvips and SQLite extension ABI compatibility are the main technical spikes.

The larger architectural decision is data ownership. Litestream can get production SQLite data onto the device and keep it fresh, but it should not be used as a bidirectional sync system. If the Nerves app must write production data, those writes should go through production or through an explicit application-level sync protocol.
