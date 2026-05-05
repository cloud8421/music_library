---
id: doc-11
title: Nerves Deployment Research — Consolidated Summary
type: other
created_date: "2026-05-04 15:25"
---

# Nerves Deployment Research — Consolidated Summary

> Synthesized from three parallel research reports (Opus 4.7 xhigh, GPT 5.5 high, Deepseek v4 Pro xhigh) on 2026-05-04.

---

## Verdict: Feasible, but read-only-first

All three reports converge: deploying the Music Library as a Nerves firmware image is **plausible**, provided the device is treated as a **read-only edge replica** with write-through to production. The central constraint is that **Litestream is not a bidirectional sync tool** — it's physical WAL replication, not application-level conflict resolution.

---

## 1. Native Dependencies — The Blockers

### 🔴 vix / libvips (Highest Risk — All Reports Agree)

- No ARM precompiled binaries. Requires platform-provided libvips (`VIX_COMPILATION_MODE=PLATFORM_PROVIDED_LIBVIPS`).
- libvips is ~30 MB with transitive deps (libjpeg, libpng, libwebp, etc.).
- Needs a **custom Nerves system** with `BR2_PACKAGE_LIBVIPS=y` in Buildroot.
- Vix loads NIF at compile time for introspection, breaking cross-compilation on stock Nerves.
- **Mitigation**: Offload image processing to production API, or commit to maintaining a custom Nerves system.

### 🟡 RustlerPrecompiled Dependencies (mdex, lumis, typst, dominant_colors)

- Standard Rustler targets (`aarch64-unknown-linux-gnu`) differ from Nerves triples (`aarch64-nerves-linux-gnu`).
- Precompiled `.so` files likely won't load; cross-compile from source with Nerves-aware Rust toolchain.
- `typst` is heavy (full typesetting engine) — consider server-side PDF generation.
- `dominant_colors` is small, low risk. `mdex`/`lumis` manageable.
- **Important**: `typst` has `@nerves_rust_target_triple_mapping` in mix.exs (Nerves-aware).

### 🟢 exqlite / ecto_sqlite3 (Good)

- Ships precompiled musl NIFs since v0.13.7 for `aarch64-linux-gnu/musl`.
- `force_build: true` compiles from source inside Nerves toolchain.
- Explicitly designed for embedded use. Well-documented for Nerves.
- Supports `load_extension` — the mechanism for loading vec0/unicode.

---

## 2. SQLite Extensions — Solvable

### vec0 (sqlite-vec)

- Pure C, no dependencies, explicitly tested on ARM / Raspberry Pi.
- Upstream glibc binaries won't work on Nerves (musl). PR #199 (musl fix) is unmerged.
- **Mitigation**: Cross-compile inside Buildroot, ship via `rootfs_overlay/`, or compile statically into exqlite at firmware build time.

### unicode (ICU extension)

- ICU is ~30 MB and deliberately excluded from Nerves base systems.
- Requires custom Nerves system with `BR2_PACKAGE_ICU=y`.
- **Low marginal cost** if already building custom system for libvips.

### Platform Detection

- Current platform detection maps Linux `aarch64` → `linux-arm64`.
- 32-bit ARM targets (RPi Zero) would fail without new binaries and mapping.
- **Recommendation**: Target RPi 4 or 5 (64-bit/aarch64) first.

---

## 3. Data Replication — The Architectural Pivot

### What Litestream Does NOT Do

- ❌ Bidirectional sync
- ❌ Conflict detection or resolution
- ❌ Multi-writer support
- ❌ Merge of divergent database histories

Litestream is asynchronous backup and disaster recovery. It streams WAL pages to S3. A second writer corrupts the generation chain.

### What LiteFS Does (and Why It Doesn't Fit)

- Multi-node SQLite replication with primary/replica model.
- Requires FUSE (needs Buildroot kernel module — unlikely on Nerves).
- Requires Consul or static leasing.
- No offline-first or intermittent-connectivity support.
- **Not viable for device ↔ cloud sync.**

### Recommended Approaches (All Three Reports Converge)

#### A. Read-Only Nerves Device (Simplest, Start Here)

- Device pulls fresh database snapshot from production.
- All writes happen on production server.
- **Sync**: Existing `/api/v1/backup`, Litestream restore, or HTTP range-request.
- **Pros**: Zero conflicts, simple, leverages existing infrastructure.
- **Cons**: No local writes.

#### B. Write-Through to Production API (Pragmatic Next Step)

- Nerves device reads local replica; mutations go to production API.
- Production remains the single SQLite writer.
- Litestream brings resulting state back down to device.
- **Pros**: No database-level conflicts. Clear ownership.
- **Cons**: Requires network for writes. App-level routing logic.

#### C. Separate Write Domains

- Production: records, embeddings, notes, record sets, artist info.
- Nerves device: scrobbles, listening stats, playback logs (separate SQLite DB).
- Each syncs via API calls.
- **Pros**: No mixed writers on any table. Codebase already structured this way (scrobbles are separate context).
- **Cons**: Two databases on device. More routing logic.

#### D. Offline-Capable Writes (Most Complex)

Options if offline writes are required:

- **Application-level outbox**: Local command log + idempotency keys + push to production on reconnect.
- **CRDTs** (Automerge, Yjs): True offline-first, no Elixir/SQLite bridge exists.
- **Event sourcing**: Append-only mutation log, replay to reconstruct state. Complex.
- **Application sync protocol**: Vector clocks, LWW, periodic pull/push. Most implementation effort.

---

## 4. Application-Specific Concerns (from GPT 5.5 report)

### Oban

- Production Oban jobs should NOT run on device (imports, enrichments, external APIs).
- Nerves deployment needs distinct Oban config: disabled, local-only queues, or maintenance-only tasks.

### Secrets (Cloak)

- Encrypted rows come with replicated data. Options: same key on device (exposure risk), don't replicate secrets, keep encrypted-but-unreadable.

### External APIs

- MusicBrainz, Last.fm, Discogs, OpenAI, etc. — decide which are disabled, proxied through production, or allowed directly.

### Assets

- Binary blobs in SQLite, content-addressed by hash — favorable for replication (immutable content).
- Large assets affect restore time and storage wear.

### Embeddings (sqlite-vec)

- Read-only similarity search on device is plausible if `vec0` loads.
- Generating embeddings requires OpenAI credentials — keep production-side.

---

## 5. Risk Summary

| Risk                          | Severity  | Mitigation                                                                |
| ----------------------------- | --------- | ------------------------------------------------------------------------- |
| vix / libvips on Nerves       | 🔴 High   | Offload image processing to production API, or build custom Nerves system |
| Data-sync strategy            | 🔴 High   | Start read-only, iterate toward write-through API                         |
| typst on embedded             | 🟡 Medium | Server-side PDF generation                                                |
| Rust NIF cross-compilation    | 🟡 Medium | Set up Nerves Rust cross-compilation; test each library                   |
| ARMv7 (RPi 3) vs AArch64      | 🟡 Medium | Target RPi 4/5 (64-bit) only                                              |
| Buildroot deps (libvips, ICU) | 🟡 Medium | Custom Nerves system; ~15-30 min Buildroot rebuild                        |
| Firmware size                 | 🟡 Medium | libvips + typst + extensions could exceed 200 MB; set 120 MB budget       |
| sqlite-vec / unicode on ARM   | 🟢 Low    | Pure C, no deps. Cross-compile in Buildroot                               |
| exqlite on Nerves             | 🟢 Low    | Designed for embedded; source compilation documented                      |
| dominant_colors               | 🟢 Low    | Tiny Rust NIF, straightforward                                            |

---

## 6. The One Key Decision

All three reports collapse into a single question:

> **Are you willing to maintain a custom Nerves system?**

- **If YES**: vix, ICU, and sqlite-vec are all solvable in the same Buildroot config. Remaining unknowns are minor (dominant_colors musl target, poncho project structure).
- **If NO**: Drop image processing, drop FTS unicode collation, drop similarity search — it becomes a different application.

---

## 7. Recommended Research Spikes (from GPT 5.5)

1. **Minimal Nerves Build** — determine if dependency tree compiles for target.
2. **SQLite Extension Load Test** — verify `unicode.so` and `vec0.so` on hardware.
3. **Read-Only Litestream Replica** — restore production DB to `/data`, confirm browsing/search.
4. **Write-Through Prototype** — pick one mutation (e.g., create note), route to production API.
5. **Offline Outbox Design** — only if offline writes are required.

---

## Sources

All three reports include extensive source references. See individual documents for full citation lists:

- `doc-8 - Opus-4.7-xhigh-analysis.md`
- `doc-9 - GPT-5.5-high-analysis.md`
- `doc-10 - Deepseek-v4-Pro-xhigh-analysis.md`
