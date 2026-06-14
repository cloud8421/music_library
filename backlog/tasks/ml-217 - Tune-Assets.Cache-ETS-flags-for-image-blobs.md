---
id: ML-217
title: Tune Assets.Cache ETS flags for image blobs
status: Done
assignee:
  - pi
created_date: "2026-06-10 10:40"
updated_date: "2026-06-14 12:20"
labels:
  - perf
dependencies: []
references:
  - lib/music_library/assets/cache.ex
  - lib/music_library_web/controllers/asset_controller.ex
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: low
ordinal: 50000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`Assets.Cache.new/0` (lib/music_library/assets/cache.ex:40) creates its ETS table with `:compressed`. Cached entries are JPEG/WebP binaries — already-compressed formats — so zlib adds CPU on every write and on every cache hit of the image-serving hot path (`AssetController`) while saving little or no memory (incompressible data carries zlib overhead).

The table also lacks `write_concurrency: true` even though `Cache.set/3` is called from concurrent request processes (it already sets `read_concurrency: true`).

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 :compressed removed and write_concurrency: true added to the Assets.Cache ETS options
- [x] #2 Existing Assets.Cache tests (set/get, TTL expiry, prune) pass unchanged
- [x] #3 Cache moduledoc note updated if it mentions storage characteristics
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

Final implementation plan:

1. Update `lib/music_library/assets/cache.ex` so `Assets.Cache.new/0` creates the named public ETS table without `:compressed`, while retaining `read_concurrency: true` and adding `write_concurrency: true`.
2. Update the `Assets.Cache` moduledoc with a concise storage-characteristics note explaining that cached values are already-encoded image binaries and ETS compression is intentionally avoided.
3. Verify with existing cache-path coverage and final checks: `test/music_library/worker/prune_asset_cache_test.exs`, `test/music_library_web/controllers/asset_controller_test.exs`, and the project precommit path for the changed Elixir/backlog files. Note: `test/music_library/assets/cache_test.exs` does not exist in this checkout, so prune/cache-path and controller tests are the relevant existing coverage.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Pre-flight complete: read docs/architecture.md and docs/project-conventions.md, loaded task ML-217 including implementation plan and measured-comment context, loaded relevant skills (testing, oban-worker, update-documentation), and reviewed the Backlog task execution workflow. No code touched yet.

Implemented the approved cache change in `lib/music_library/assets/cache.ex`: removed ETS `:compressed`, added `write_concurrency: true`, and documented why encoded image binaries are not ETS-compressed. Verification loop: `mix test test/music_library/worker/prune_asset_cache_test.exs test/music_library_web/controllers/asset_controller_test.exs` passed (15 tests). There is no `test/music_library/assets/cache_test.exs` in this checkout; existing cache coverage is through `PruneAssetCacheTest` plus asset-controller cache-path tests.

Final verification: `STAGED="lib/music_library/assets/cache.ex backlog/tasks/ml-217" mise run dev:precommit` completed successfully. It ran Credo, Sobelow, gettext check, mix format check, the partitioned test suite (1,177 tests/doctests total across 4 partitions), and backlog Prettier. The mix format step emitted existing `module Prettier is not loaded` log lines but did not fail; all checks exited successfully.

<!-- SECTION:NOTES:END -->

## Comments

<!-- COMMENTS:BEGIN -->

author: pi
created: 2026-06-14 12:15

---

Verification measurement (2026-06-14):

- Current dev `assets` table: 1,535 rows, 553,672,670 payload bytes (1,532 JPEG, 2 WebP, 1 PNG).
- Full dataset in ETS with only the `:compressed` flag varied (`[:public, read_concurrency: true]` vs `[:public, :compressed, read_concurrency: true]`): plain table overhead 402,432 bytes; compressed table overhead 365,592 bytes. Savings: 36,840 bytes, about 0.0067% of image payload size. VM binary memory delta was effectively identical (~553.98 MB) for both, so the large image binaries are still stored as ref-counted binaries rather than compressed into the ETS table body.
- Operation microbench on 100 real asset blobs (38.34 MB), 100,000 inserts and 500,000 cache-hit lookups: compressed inserts 16.138 ms vs plain 9.362 ms (1.72x); compressed lookups 111.378 ms vs plain 93.532 ms (1.19x). Compressed saved 2,400 bytes of table overhead for that sample.
- Cache-like transformed sample, 50 resized width-300 WebP entries (740,418 bytes): compressed saved 1,200 bytes but was 1.50x slower on inserts and 1.34x slower on lookups. JPEG sample was similar (1,048,514 bytes; 1.71x slower inserts, 1.19x slower lookups, same 1,200-byte saving).

## Conclusion: the practical claim is verified: `:compressed` saves negligible memory for image cache entries and adds measurable operation overhead. Nuance: for large binaries, ETS `:compressed` does not appear to compress the image payload bytes themselves; the saved memory is only small table/object overhead, while the payload remains in VM binary memory.

<!-- COMMENTS:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Implemented ML-217 by tuning the `Assets.Cache` ETS table for encoded image blobs.

Changes:

- Removed `:compressed` from `Assets.Cache.new/0`.
- Added `write_concurrency: true` while keeping `:named_table`, `:public`, and `read_concurrency: true`.
- Added a moduledoc storage note explaining that cached values are already-encoded image binaries and ETS compression is intentionally avoided on the asset-serving hot path.

Why:

- The measurement captured on the task showed `:compressed` saves negligible memory for JPEG/WebP cache entries while adding measurable insert and lookup overhead.

Verification:

- `mix test test/music_library/worker/prune_asset_cache_test.exs test/music_library_web/controllers/asset_controller_test.exs` — 15 tests passed.
- `STAGED="lib/music_library/assets/cache.ex backlog/tasks/ml-217" mise run dev:precommit` — completed successfully, including Credo, Sobelow, gettext check, mix format check, partitioned test suite (1,177 tests/doctests), and backlog Prettier.

Notes:

- There are no Definition of Done checklist items on this task.
- `test/music_library/assets/cache_test.exs` does not exist in this checkout; existing cache coverage is through prune-worker tests and asset-controller cache-path tests.
- The precommit format step emitted existing `module Prettier is not loaded` log lines but did not fail.
<!-- SECTION:FINAL_SUMMARY:END -->
