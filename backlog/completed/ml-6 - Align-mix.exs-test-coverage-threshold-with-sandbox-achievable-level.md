---
id: ML-6
title: Align mix.exs test coverage threshold with sandbox-achievable level
status: Done
assignee: []
created_date: "2026-04-20 08:48"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/177"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-16 · updated 2026-04-17 · closed 2026-04-17_

## Summary

`mix.exs` sets a coverage threshold of 90 % but actual coverage is 75.77 %. Most of the 14.2-point gap is modules that legitimately cannot execute in the Ecto sandbox: cron-only workers (`RepoVacuum`, `RepoOptimize`, `SendRecordsOnThisDayEmail`, `RefreshScrobbles`) and Mix tasks. Per project conventions, tests for untestable sandbox operations are not written.

## Evidence

Current coverage output: 75.77 % (720 tests, `mix test --cover`).

0 % modules that cannot be covered under the sandbox convention:

- `MusicLibrary.Worker.RepoVacuum`
- `MusicLibrary.Worker.RepoOptimize`
- `MusicLibrary.Worker.SendRecordsOnThisDayEmail`
- `MusicLibrary.Worker.RefreshScrobbles`
- `MusicLibrary.Worker.BackfillScrobbledTracks`
- Several `Mix.Tasks.*`

## Why It Matters

A red coverage check on `mix test --cover` that is structurally unachievable trains contributors to ignore the signal. Either the threshold should reflect reality, or the untestable modules should be decorated for exclusion.

## Fix (options)

1. Lower the threshold to a realistic value (e.g. 85 %) that fails when new gaps appear but passes today.
2. Decorate the unreachable modules with `@moduledoc tags: [:skip_coverage]` (or similar) and exclude them via `test_coverage: [ignore_modules: [...]]` in `mix.exs`.

Option 2 is preferable because it keeps the threshold aspirational and surfaces the exclusion list.

## Acceptance Criteria

<!-- AC:BEGIN -->

- `mix test --cover` passes under its configured threshold
- Untestable modules are explicitly enumerated somewhere (config, moduledoc, or both)
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 `mix test --cover` passes under its configured threshold
- [ ] #2 Untestable modules are explicitly enumerated somewhere (config, moduledoc, or both)
<!-- AC:END -->
