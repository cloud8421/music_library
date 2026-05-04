---
id: ML-40
title: Two different pagination query styles across contexts
status: Done
assignee: []
created_date: "2026-04-20 08:53"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/137"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-25 · updated 2026-03-25 · closed 2026-03-25_

## Description

Contexts use two different patterns for handling offset/limit pagination:

**Style 1 — Keyword.get with defaults** (used by `Collection`, `RecordSets`):

```elixir
offset = Keyword.get(opts, :offset, 0)
limit = Keyword.get(opts, :limit, @pagination[:default_page_size])
```

**Style 2 — Case statements** (used by `ScrobbleRules`, `OnlineStoreTemplates`):

```elixir
case opts[:offset] do
  nil -> ...
  offset -> ...
end
```

## Expected behavior

Standardize on one approach. The `Keyword.get` pattern is simpler and more common in the codebase.

## Found during

Codebase consistency audit (2026-03-25)

<!-- SECTION:DESCRIPTION:END -->
