---
id: ML-151
title: Document Assets.Cache TTL and cache invalidation strategy
status: To Do
assignee: []
created_date: '2026-04-30 10:48'
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
- [ ] #1 `Assets.Cache` `@moduledoc` documents the TTL value and where it is configured
- [ ] #2 The invalidation strategy (TTL-based expiry) is explained with rationale
- [ ] #3 Any architectural implications are captured in `docs/architecture.md`
<!-- AC:END -->
