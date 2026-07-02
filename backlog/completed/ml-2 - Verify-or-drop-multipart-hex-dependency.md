---
id: ML-2
title: Verify or drop multipart hex dependency
status: Done
assignee: []
created_date: "2026-04-20 08:44"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/182"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-16 · updated 2026-04-16 · closed 2026-04-16_

## Summary

`mix.exs` lists `{:multipart, "~> 0.6.0"}` but there are zero direct `Multipart.*` references in `lib/`. It is likely needed transitively for Swoosh Mailgun attachments, but worth confirming.

## Evidence

- `mix.exs` — `{:multipart, "~> 0.6.0"}` declared as a direct dep
- Grep for `Multipart.` in `lib/` returns no matches
- Endpoint's `parsers: [:multipart]` is the Plug.Parsers atom, not this hex package

## Fix (decision tree)

1. Remove the dep from `mix.exs`
2. Run `mix deps.get` + `mix compile`
3. Run `mix test` and specifically the Mailer-sending paths (`RecordsOnThisDayEmail`, `ErrorTracker.ErrorNotifier.Email`)
4. If something fails, restore the dep and add a comment in `mix.exs` noting what relies on it
5. If everything passes, keep it removed

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Decision recorded: either dep removed, or dep retained with comment explaining transitive need

<!-- AC:END -->
