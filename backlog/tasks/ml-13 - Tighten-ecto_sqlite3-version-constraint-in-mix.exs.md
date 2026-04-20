---
id: ML-13
title: Tighten ecto_sqlite3 version constraint in mix.exs
status: To Do
assignee: []
created_date: '2026-04-20 08:50'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/170'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-16 · updated 2026-04-16_

## Summary

`mix.exs:52` declares `{:ecto_sqlite3, ">= 0.0.0"}` — the loosest possible constraint. The lockfile pins 0.22.0.

## Evidence

```elixir
{:ecto_sqlite3, ">= 0.0.0"}
```

All other production deps use `~>` with at least a major pin (e.g. `ecto_sql, "~> 3.10"`, `oban, "~> 2.21"`).

## Fix

Change to `{:ecto_sqlite3, "~> 0.22"}`. Matches the installed major; prevents accidental upgrade on a fresh `mix deps.get`.

## Acceptance Criteria
<!-- AC:BEGIN -->
- `mix deps.get` still resolves cleanly
- `mix test` passes
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 `mix deps.get` still resolves cleanly
- [ ] #2 `mix test` passes
<!-- AC:END -->
