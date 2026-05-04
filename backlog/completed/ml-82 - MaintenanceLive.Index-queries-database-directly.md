---
id: ML-82
title: MaintenanceLive.Index queries database directly
status: Done
assignee: []
created_date: "2026-04-20 08:57"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/93"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-05 · updated 2026-03-05 · closed 2026-03-05_

## Priority: Medium

## Description

`lib/music_library_web/live/maintenance_live/index.ex` imports `Ecto.Query` and calls `BackgroundRepo.one()`, `Repo.vacuum()`, `Repo.optimize()` directly. This violates the project convention that "LiveViews never query the database directly — they call context functions."

This is a dev/admin-only view, so impact is limited, but it breaks the established pattern.

## Expected behavior

Extract database queries into a context module (e.g., `MusicLibrary.Maintenance`).

## Source

From technical debt audit (2026-03-05).

<!-- SECTION:DESCRIPTION:END -->
