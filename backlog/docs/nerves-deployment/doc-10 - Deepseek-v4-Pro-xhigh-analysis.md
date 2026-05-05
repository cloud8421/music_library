---
id: doc-10
title: "Deepseek v4 Pro, xhigh analysis"
type: other
created_date: "2026-05-04 15:11"
---

# Nerves Deployment Feasibility Analysis for Music Library

> Research report — do not implement. May 2026.

## Overview

This report assesses the viability of deploying the Music Library application (a
Phoenix LiveView app backed by SQLite + Litestream) as a Nerves firmware image.
Three areas were identified as potential challenges:

1.  **Libraries with native extensions (NIFs)** — do they offer precompiled ARM
    binaries or can they be cross-compiled?
2.  **SQLite extensions** — `vec0` (sqlite-vec) and `unicode` — already support
    Linux/ARM on paper, but are they tested on Nerves targets?
3.  **Data replication** — the production instance uses Litestream for backup. How
    would a Nerves device replicate data, and what happens with write conflicts?

Each area is analysed below, followed by a summary of risks and recommended next
steps.

---

## 1. Native-extensions audit

Every dependency that ships a NIF or binary artefact was reviewed for ARM /
Nerves compatibility. Dev‑only tools (esbuild, tailwind, credo, etc.) are
excluded — they never reach the firmware.

| Dependency                          | Purpose                               | NIF type                                | Precompiled ARM?                                                            | Nerves feasibility                                                                                                                                                                                                             |
| ----------------------------------- | ------------------------------------- | --------------------------------------- | --------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| **exqlite** → `ecto_sqlite3`        | SQLite driver                         | C NIF (`cc_precompiler`)                | ✅ `aarch64-linux-gnu/musl` (no `armv7-*`)                                  | **🟢 Good** — `force_build: true` compiles from source inside the Nerves toolchain. Explicitly mentioned in Exqlite’s README as an embedded use-case.                                                                          |
| **vix** → libvips                   | Image processing (covers, thumbnails) | C NIF (`elixir_make`)                   | ❌ No ARM binaries advertised                                               | **🔴 High risk** — libvips is ~30 MB with transitive deps (libjpeg, libpng, libwebp, etc.). Each needs Buildroot integration or cross‑compilation. Biggest blocker for a lean firmware.                                        |
| **mdex** → comrak + ammonia         | Markdown → HTML                       | Rust NIF (RustlerPrecompiled)           | ⚠️ Standard Rustler targets (`aarch64-unknown-linux-gnu`, possibly `arm-*`) | **🟡 Needs cross‑compilation** — RustlerPrecompiled targets use different triples than Nerves (`aarch64-nerves-linux-gnu`). Precompiled `.so` likely won’t load. Cross‑compile from source with a Nerves‑aware Rust toolchain. |
| **lumis** → tree‑sitter             | Syntax highlighting (in mdex)         | Rust NIF (RustlerPrecompiled)           | Same as mdex                                                                | **🟡 Same situation** — part of the mdex stack. Tree‑sitter grammars add per‑language compilation but the NIF itself is manageable.                                                                                            |
| **typst**                           | PDF generation (tracklists)           | Rust NIF (RustlerPrecompiled)           | Same as mdex                                                                | **🔴 Heavy** — a full typesetting engine. Large binary, plus the same target‑triple mismatch. Likely overkill for embedded PDFs.                                                                                               |
| **dominant_colors** → kmeans_colors | Colour extraction from covers         | Rust NIF (`rustler_precompiled ~> 0.7`) | Same as mdex                                                                | **🟢 Small** — trivial NIF. Cross‑compilation is straightforward. Low risk.                                                                                                                                                    |
| **esbuild**                         | JS bundling                           | Go binary                               | —                                                                           | **N/A** — dev only, never deployed.                                                                                                                                                                                            |
| **tailwind**                        | CSS generation                        | Go binary                               | —                                                                           | **N/A** — dev only, never deployed.                                                                                                                                                                                            |

### Target‑architecture specifics

| Target    | CPU                       | Nerves toolchain triple        | Precompiled‑binary match?                                                         |
| --------- | ------------------------- | ------------------------------ | --------------------------------------------------------------------------------- |
| RPi 4 / 5 | Cortex‑A72 / A76 (64‑bit) | `aarch64-nerves-linux-gnu`     | ⚠️ `aarch64-linux-gnu` _may_ be ABI‑compatible (exqlite). Rust NIFs need rebuild. |
| RPi 3     | Cortex‑A53 (32‑bit)       | `armv7-nerves-linux-gnueabihf` | ❌ No precompiled binaries match. Everything must be compiled from source.        |

**Recommendation**: Target RPi 4 or 5 (64‑bit) first — the precompiled ecosystem is
far better and the 32‑bit path adds unnecessary friction.

---

## 2. SQLite extensions

The application loads two run‑time extensions via Exqlite’s `load_extensions`
config:

| Extension   | Source                                                                       | ARM status             | Notes                                                                                                                                                 |
| ----------- | ---------------------------------------------------------------------------- | ---------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| **vec0**    | [sqlite-vec](https://github.com/asg017/sqlite-vec)                           | ✅ **Good**            | “Written in pure C, no dependencies, runs anywhere SQLite runs (… Raspberry Pis, etc.)” — explicitly tested on ARM. Compilable for any Nerves target. |
| **unicode** | likely [sqlean](https://github.com/nalgeon/sqlean) (`text` module or bundle) | ✅ **ARM64 available** | Sqlean ships `sqlean-linux-arm64.zip`. For ARMv7, compile from C source.                                                                              |

### Loading mechanism

The project already uses an architecture‑aware directory layout:

```elixir
config :myapp, Myapp.Repo,
  load_extensions: ["./priv/sqlite/#{arch_dir}/vector0"]
```

This pattern extends naturally to Nerves — compile the `.so` files with the Nerves
cross‑compiler, place them in the appropriate arch subdirectory, and Exqlite will
load them at connection time.

**Unknown**: Whether the `unicode` extension is built from the exact same sqlean
release as production, or compiled independently. Sync the build flags and version
to avoid subtle behavioural differences.

---

## 3. Data replication & conflict resolution

This is the **hardest problem** and the most architecturally open of the three.

### What Litestream does (and doesn’t)

| Capability                          | Litestream | Needed for device ↔ cloud sync |
| ----------------------------------- | ---------- | ------------------------------ |
| Unidirectional backup (app → S3)    | ✅         | ❌                             |
| Disaster recovery (restore from S3) | ✅         | ❌                             |
| Bidirectional sync                  | ❌         | ✅                             |
| Conflict detection / resolution     | ❌         | ✅                             |
| Multi‑writer support                | ❌         | ✅                             |

Litestream is purely an asynchronous backup tool. It continuously streams WAL pages
to S3. It has **no mechanism** for a second instance to push writes back, no merge
strategy, and no conflict detection. Adding a Nerves device that writes to the same
database file would corrupt the Litestream generation (or create a parallel one that
cannot be merged).

### What LiteFS does (and doesn’t)

[LiteFS](https://github.com/superfly/litefs) (same creators, different project)
provides multi‑node SQLite replication with a primary/replica model:

- ✅ Automatic failover via distributed lease (Consul)
- ✅ LTX‑based transaction‑log replication
- ✅ Built‑in HTTP proxy for write‑forwarding to the primary
- ❌ Requires FUSE (needs a Buildroot kernel module)
- ❌ Requires Consul or static leasing
- ❌ **Replicas are read‑only** — only one writer at a time
- ❌ Designed for same‑region clusters, not device ↔ cloud
- ❌ No offline‑first or intermittent‑connectivity support

**LiteFS does not fit** the device‑sync use case. If the Nerves device goes offline,
accumulates writes, then reconnects, LiteFS has no way to merge those writes onto
the primary.

### Realistic approaches

#### A. Read‑only Nerves device (simplest, safest)

The Nerves device is a read‑only replica. All writes happen on the production
server. The device periodically pulls a fresh database snapshot.

- **Sync**: `GET /api/v1/backup` (already exists), Litestream restore, or HTTP
  range‑request to fetch a compressed DB.
- **Pros**: Zero conflicts, simple to implement, leverages existing backup API.
- **Cons**: No local writes — can’t add records, update notes, or scrobble from
  the device.

#### B. Separate write domains (pragmatic)

Never write the same record type from both sides:

- **Production server**: records, embeddings, notes, record sets, artist info.
- **Nerves device**: scrobbles, listening stats, playback logs.
- Each instance has its own SQLite database. They sync via API calls (e.g., device
  pushes scrobbles to production, production pushes new records to device).

- **Pros**: No database‑level conflicts. Clear ownership boundaries.
- **Cons**: App‑level routing logic. Two separate databases on the device.

#### C. CRDT‑backed data model (most robust)

Model the subset of data writable on both sides using Conflict‑free Replicated Data
Types (CRDTs).

- **Libraries**: [Automerge](https://automerge.org/), [Yjs](https://yjs.dev/),
  custom CRDT stores.
- **Pros**: True offline‑first, automatic conflict resolution, no central
  authority needed.
- **Cons**: Requires wrapping your data in CRDT types. No mature Elixir CRDT ↔
  SQLite bridge. Significant architecture change.

#### D. Event sourcing with log shipping

Write all mutations as an append‑only event log. Ship the log between instances.
Replay to reconstruct state.

- **Pros**: Natural fit with SQLite (append to a `mutations` table). Full audit
  trail.
- **Cons**: Requires event‑schema design, log compaction, eventual consistency
  handling.

#### E. Application‑level sync protocol

Define a custom sync protocol with:

- Vector clocks or timestamps for causality tracking.
- Last‑write‑wins (LWW) or manual conflict resolution.
- Periodic pull/push of changed records since the last sync point.

- **Pros**: Domain‑specific, can optimise for exact data shapes.
- **Cons**: Most implementation effort. Easy to get wrong.

### Litestream’s role on the device

Even with a sync strategy in place, Litestream could still run on the Nerves device
for **local disaster recovery** — streaming the device’s own WAL to a separate S3
path. This is independent from the production Litestream instance.

---

## Summary of risks

| Risk                                   | Severity  | Mitigation                                                                                                            |
| -------------------------------------- | --------- | --------------------------------------------------------------------------------------------------------------------- |
| **vix / libvips on Nerves**            | 🔴 High   | Replace image processing with a lighter alternative, or offload to the production server via API.                     |
| **Data‑sync strategy**                 | 🔴 High   | No off‑the‑shelf solution. Start with read‑only replica (option A), iterate toward separate write domains (option B). |
| **typst on embedded**                  | 🟡 Medium | Switch to server‑side PDF generation; client downloads the result.                                                    |
| **Rust NIF cross‑compilation**         | 🟡 Medium | Set up Nerves Rust cross‑compilation. Works but adds build complexity. Each library needs individual testing.         |
| **ARMv7 (RPi 3) vs AArch64 (RPi 4/5)** | 🟡 Medium | RPi 4/5 (64‑bit) has much better precompiled‑binary support. RPi 3 requires everything compiled from source.          |
| **Buildroot package deps (libvips)**   | 🟡 Medium | Each transitive C library needs a Buildroot package definition or a custom cross‑compile step.                        |
| **Firmware size**                      | 🟡 Medium | libvips + typst + sqlite extensions → image could exceed 200 MB. Typical Nerves firmware is 20–80 MB.                 |
| **sqlite‑vec on ARM**                  | 🟢 Low    | Explicitly supported. Pure C, no deps. Compiles trivially with the Nerves toolchain.                                  |
| **exqlite on Nerves**                  | 🟢 Low    | Designed for embedded use. Source compilation well‑supported and documented.                                          |
| **dominant_colors**                    | 🟢 Low    | Tiny Rust NIF. Straightforward cross‑compilation.                                                                     |

---

## Recommended next steps (if proceeding)

1.  **Target RPi 4 or 5 (64‑bit)** — significantly better precompiled binary
    ecosystem and larger RAM for Phoenix + Oban.
2.  **Start with a read‑only firmware** — pull database snapshots from the
    production server via the existing `/api/v1/backup` (or `/health`) endpoint.
    Don’t write locally until a sync strategy is decided.
3.  **Audit which features to keep on‑device** — consider dropping image
    processing (vix) and PDF generation (typst) from the embedded build, or
    replacing them with lighter alternatives / server‑side APIs.
4.  **Benchmark firmware size incrementally** — start with bare Phoenix + SQLite,
    add extensions, measure. Set a hard size budget (e.g., 120 MB).
5.  **Design the sync protocol as a separate project** — this is the most complex
    piece. Prototype with a read‑only client first, then evaluate CRDTs, event
    sourcing, or application‑level sync based on actual write patterns.
