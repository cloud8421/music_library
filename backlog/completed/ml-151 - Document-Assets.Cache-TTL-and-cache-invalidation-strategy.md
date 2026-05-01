---
id: ML-151
title: Document Assets.Cache TTL and cache invalidation strategy
status: Done
assignee: []
created_date: '2026-04-30 10:48'
updated_date: '2026-04-30 12:04'
labels:
  - documentation
  - assets
dependencies: []
references:
  - lib/music_library/assets/cache.ex
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
`Assets.Cache` (`lib/music_library/assets/cache.ex`) uses an ETS table with TTL for caching binary asset data. When assets are updated (e.g., a new cover is uploaded), the cache relies on TTL-based expiry — there is no explicit invalidation.

The TTL duration and the rationale for TTL-only invalidation (vs. explicit purge) are not documented in the module or in the architecture docs.

Add a `@moduledoc` to `Assets.Cache` that explains:
- The TTL value and where it's configured
- The invalidation strategy (TTL-based expiry) and why explicit invalidation is/isn't needed
- Update `docs/architecture.md` if the design decision has architectural relevance
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 `Assets.Cache` `@moduledoc` documents the TTL value and where it is configured
- [x] #2 The invalidation strategy (TTL-based expiry) is explained with rationale
- [x] #3 Any architectural implications are captured in `docs/architecture.md`
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Plan

### What we're documenting

`Assets.Cache` is an ETS-based cache for transformed binary asset data. Assets are stored by SHA256 hash and are immutable (write-once). The cache key is `{payload, format}`.

### Key facts to document

- **TTL**: `@one_week_seconds` = 7 days, defined as a module attribute
- **Pruning**: `prune/0` defaults to 7-day TTL, called every 12h by `PruneAssetCache` Oban cron worker
- **Invalidation strategy**: TTL-based expiry only — no explicit invalidation

### Rationale

Explicit invalidation isn't needed because:
1. Assets are content-addressable (SHA256) and immutable — updates create new hashes, so old entries are never requested again
2. Periodic pruning (every 12h) cleans up stale entries
3. ETS table is in-memory, cleared on restart

### Changes

1. Expand `@moduledoc` in `lib/music_library/assets/cache.ex`
2. Expand the `Assets.Cache` entry in `docs/architecture.md` Business Logic Modules table
<!-- SECTION:PLAN:END -->
