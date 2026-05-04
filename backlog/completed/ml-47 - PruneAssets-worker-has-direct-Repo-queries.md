---
id: ML-47
title: PruneAssets worker has direct Repo queries
status: Done
assignee: []
created_date: "2026-04-20 08:53"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/130"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-25 · updated 2026-03-25 · closed 2026-03-25_

## Description

`PruneAssets` worker (`lib/music_library/worker/prune_assets.ex:16-35`) builds Ecto queries and calls `Repo.delete_all` directly, violating the convention that workers are thin wrappers delegating to context modules. All other workers delegate to context functions. This logic should live in `MusicLibrary.Assets`.

## Expected behavior

Extract the query and deletion into an `Assets.prune_unreferenced/0` context function, and have the worker call it.

## Found during

Codebase consistency audit (2026-03-25)

<!-- SECTION:DESCRIPTION:END -->
