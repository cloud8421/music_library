---
id: ML-38
title: Inconsistent Logger style in workers (eager vs lazy)
status: Done
assignee: []
created_date: "2026-04-20 08:53"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/139"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-25 · updated 2026-03-25 · closed 2026-03-25_

## Description

Workers use two different Logger styles:

**Lazy (preferred)** — `PruneAssetCache` (`lib/music_library/worker/prune_asset_cache.ex:12`):

```elixir
Logger.info(fn -> "Pruned #{prune_count} old cached assets..." end)
```

**Eager** — `PruneAssets` (`lib/music_library/worker/prune_assets.ex:34`):

```elixir
Logger.info("Pruned #{count} unreferenced assets.")
```

## Expected behavior

Standardize on lazy logging with `fn -> ... end` for efficiency (avoids string interpolation when log level is filtered out).

## Found during

Codebase consistency audit (2026-03-25)

<!-- SECTION:DESCRIPTION:END -->
