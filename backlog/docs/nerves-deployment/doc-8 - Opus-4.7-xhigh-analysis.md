---
id: doc-8
title: 'Opus 4.7, xhigh analysis'
type: other
created_date: '2026-05-04 15:08'
updated_date: '2026-05-04 15:10'
---
# Nerves Deployment Research — Findings

Three parallel research agents covered NIFs, SQLite extensions, and Litestream replication semantics. The user's concerns were well-founded: there are real blockers, but most are solvable with custom Nerves system work. The Litestream question reframes the architecture more than expected.

## 1. Native libraries (NIFs on aarch64-linux-musl)

| Library | aarch64-gnu | aarch64-musl | Status |
|---|---|---|---|
| `mdex` | ✅ | ✅ | Fine |
| `lumis` | ✅ | ✅ | Fine |
| `typst` | ✅ | ✅ | **Nerves-aware** — has `@nerves_rust_target_triple_mapping` in mix.exs |
| `ecto_sqlite3` / `exqlite` | ✅ | ✅ | Driver fine; designed with embedded use in mind. Extensions are the issue (see §2) |
| `dominant_colors` | likely | unknown | Verify GitHub releases; if missing, request musl target from maintainer |
| `vix` | partial | ❌ | **Major blocker** |
| `cloak_ecto` | n/a | n/a | Pure Elixir + `:crypto` |

**`vix` is the dominant blocker.** Two compounding issues:

- It loads the NIF at *compile time* (macro-driven introspection), which breaks cross-compilation on stock Nerves systems. fhunleth (Nerves core) discussed this in a 2023 ElixirForum thread; the conclusion was "no easy Elixir-level fix."
- libvips itself is not in `nerves_system_rpi4` / `nerves_system_rpi5`. You'd need a **custom Nerves system** with `BR2_PACKAGE_LIBVIPS=y` in Buildroot, then `VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS`.

This is doable (15–30 min Buildroot rebuild, well-documented) but it commits you to maintaining a custom Nerves system. That single decision affects everything downstream — once you're building custom systems, ICU and sqlite-vec become "while we're at it" additions.

**General Phoenix-on-Nerves status (2025):** Pattern is established but niche. Underjord's "LiveView on Nerves" guide is the canonical reference; a poncho project (sibling `ui` + `firmware`) is preferred over umbrella. No widely-cited "production Phoenix LiveView on Nerves at non-hobby scale" guide exists — most published examples are thermostats and birdhouses.

## 2. SQLite extensions

Both extensions are blockers on stock Nerves systems for the same root reason — Nerves uses musl, prebuilt binaries assume glibc.

**`sqlite-vec` (`vec0`):**

- Upstream publishes `linux-aarch64` but it's **glibc** — won't `dlopen` on Nerves.
- No musl prebuilt exists; PR #199 fixes the musl compile but is **unmerged**.
- The `sqlite_vec` Hex wrapper (Joel Paul Koch's) downloads the glibc binary and would fail at runtime.
- Mitigation: cross-compile inside Buildroot, ship via `rootfs_overlay/`. Or compile statically into exqlite at firmware build time (recommended pattern from the SQLCipher-on-Nerves ElixirForum thread).

**`unicode` (ICU) extension:**

- ICU is ~30 MB and deliberately excluded from Nerves base systems.
- Requires a custom Nerves system with `BR2_PACKAGE_ICU=y`.
- If you're already building custom for `vix`, the marginal cost is minimal.

**Good news for `exqlite`:** Driver itself ships precompiled musl NIFs (since v0.13.7), supports `load_extension`, and has been used on Nerves in production (the SQLCipher thread). The complexity is purely in shipping the extension `.so`s built against the same musl toolchain.

## 3. Litestream replication — this is the architectural pivot

**Headline:** Litestream is *not* a multi-master replicator. It's a one-way backup tool. If the Nerves device writes locally, those writes are lost on the next restore — no conflict detection, no reconciliation, no merge.

**Two viable replica modes today (both newer than the docs you may remember):**

1. **VFS read replica** (stable, in `litestream.io/guides/vfs/`): Nerves device queries S3-backed replica directly. ~1 minute staleness matches your sync interval. Writes return `"litestream is a read only vfs"` at the SQLite layer. **Requires CGO** — verify this works in your Nerves build.
2. **Restore-then-poll**: simpler, no CGO. Restore on startup, periodically re-restore. Live replication via the embedded HTTP server existed but the example repo was **archived November 2023** — treat as experimental.

**For the architectures you'd consider:**

- **Read-only Nerves device** (browse music library at home, no edits) — Litestream VFS replica works, modulo CGO. This is the simplest path.
- **Read-write Nerves device** (record listening, edit notes) — Litestream alone is insufficient. Three options:
  1. **Split databases**: music library is read-only via Litestream; a separate small SQLite on the device captures writes and pushes to the production API out-of-band. Cleanest fit for your existing app shape, since scrobbles are already a separate domain.
  2. **LiteFS** (Fly.io's project): true primary/replica with write-forwarding. Requires FUSE — not viable on Nerves without kernel module support, so likely off the table.
  3. **Writes go directly to production API**: Nerves device calls the prod Phoenix JSON API for any write; reads are local. Requires the device to be online for writes (acceptable for a home device).
- **Other distributed-SQLite options** — rqlite (Raft, kills write throughput), Marmot (NATS-based CDC, eventual consistency), cr-sqlite (CRDTs). All exist; all are heavier than the problem warrants for one home device.

## Synthesis: where the unknowns concentrate

The three concerns aren't independent — they collapse into **one decision**: are you willing to maintain a custom Nerves system?

- If **yes**: `vix`, ICU, and `sqlite-vec` are all solvable in the same Buildroot config. The remaining unknowns are minor (`dominant_colors` musl target, exact poncho structure for the existing umbrella-style codebase).
- If **no**: the application as currently architected cannot run on Nerves. You'd have to drop image processing, drop FTS unicode collation, drop similarity search — at which point it's a different application.

The **biggest non-obvious unknown** is the Litestream architecture decision. Going read-only on the Nerves side is dramatically simpler than supporting writes, and it covers most of the value (browsing, search, AI chat against the local collection). Splitting writes to a separate small DB that pushes to prod is the natural compromise — and your codebase is already structured to support it (scrobbles are a separate context, notes are a separate schema).

**Suggested next step if you want to proceed:** prototype a custom `nerves_system_rpi5` with libvips + ICU on a feature branch, before touching the application. That single artifact resolves three of the four major risks; everything else is application-layer work that can be done iteratively.

---

## Sources

### NIF / Phoenix-on-Nerves
- [Underjord: LiveView on Nerves](https://underjord.io/liveview-on-nerves.html)
- [ElixirForum: Cross Compiling with NIF as compilation dependency (vix/Nerves thread)](https://elixirforum.com/t/cross-compiling-with-nif-as-compilation-dependency/59821)
- [Nerves docs: Compiling Non-BEAM Code](https://hexdocs.pm/nerves/compiling-non-beam-code.html)
- [rustler_precompiled Precompilation Guide](https://hexdocs.pm/rustler_precompiled/precompilation_guide.html)
- [mdex GitHub releases (NIF targets)](https://github.com/leandrocp/mdex/releases)
- [lumis GitHub releases](https://github.com/leandrocp/lumis)
- [typst Elixir GitHub releases](https://github.com/Hermanverschooten/typst/releases)
- [vix HexDocs README](https://hexdocs.pm/vix/readme.html)
- [exqlite README](https://hexdocs.pm/exqlite/readme.html)
- [NervesConf 2024 Talks thread](https://elixirforum.com/t/nervesconf-2024-talks/75205)
- [Customizing Your Nerves System](https://hexdocs.pm/nerves/customizing-systems.html)

### SQLite extensions
- [Releases · asg017/sqlite-vec](https://github.com/asg017/sqlite-vec/releases)
- [Fix for musl compile PR #199 · asg017/sqlite-vec](https://github.com/asg017/sqlite-vec/pull/199)
- [Build and install exqlite with sqlcipher into nerves rpi5 image — ElixirForum](https://elixirforum.com/t/build-and-install-exqlite-with-sqlcipher-into-nerves-rpi5-image/75089)
- [Concerning warning compiling under Nerves · Issue #166 · elixir-sqlite/exqlite](https://github.com/elixir-sqlite/exqlite/issues/166)
- [Compiling sqlite-vec — Alex Garcia](https://alexgarcia.xyz/sqlite-vec/compiling.html)
- [GitHub — joelpaulkoch/sqlite_vec](https://github.com/joelpaulkoch/sqlite_vec)
- [Advanced Configuration — Nerves](https://hexdocs.pm/nerves/advanced-configuration.html)

### Litestream
- [Live Read Replication — Litestream (tip)](https://tip.litestream.io/guides/read-replica/)
- [VFS Read Replicas — Litestream](https://litestream.io/guides/vfs/)
- [How it works — Litestream](https://litestream.io/how-it-works/)
- [Tips & Caveats — Litestream](https://litestream.io/tips/)
- [Alternatives — Litestream](https://litestream.io/alternatives/)
- [Litestream: Revamped — Fly.io Blog](https://fly.io/blog/litestream-revamped/)
- [benbjohnson/litestream-read-replica-example (archived 2023)](https://github.com/benbjohnson/litestream-read-replica-example)
- [Live read replicas — Issue #8](https://github.com/benbjohnson/litestream/issues/8)
- [LiteFS vs Litestream vs rqlite vs dqlite on VPS in 2025](https://onidel.com/blog/sqlite-replication-vps-2025)
- [Marmot distributed SQLite replicator](https://github.com/maxpert/marmot)
- [mvSQLite](https://github.com/losfair/mvsqlite)
- [cr-sqlite](https://github.com/vlcn-io/cr-sqlite)
