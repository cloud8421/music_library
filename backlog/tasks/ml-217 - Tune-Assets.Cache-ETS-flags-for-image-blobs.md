---
id: ML-217
title: Tune Assets.Cache ETS flags for image blobs
status: To Do
assignee: []
created_date: "2026-06-10 10:40"
updated_date: "2026-06-10 10:56"
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

- [ ] #1 :compressed removed and write_concurrency: true added to the Assets.Cache ETS options
- [ ] #2 Existing Assets.Cache tests (set/get, TTL expiry, prune) pass unchanged
- [ ] #3 Cache moduledoc note updated if it mentions storage characteristics
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. In Assets.Cache.new/0, remove `:compressed` and add `write_concurrency: true` (keep :named_table, :public, read_concurrency: true).
2. Review the moduledoc (it documents cache design) and add a line noting entries are pre-compressed image binaries, hence no ETS compression.
3. Run test/music_library/assets/cache_test.exs and the asset controller tests, then precommit.
<!-- SECTION:PLAN:END -->
