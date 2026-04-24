---
id: ML-11
title: Telemetry.Storage GenServer funnels synchronous SQLite writes
status: Done
assignee: []
created_date: '2026-04-20 08:49'
updated_date: '2026-04-24 09:29'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/172'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-16 · updated 2026-04-16_

## Summary

`MusicLibraryWeb.Telemetry.Storage` is a single named GenServer that receives a cast for every telemetry event and performs two synchronous SQLite writes per event. A page with 10 DB queries plus a render can push 30+ messages into this one mailbox, all queued behind serial disk I/O.

## Evidence

- `lib/music_library_web/telemetry/storage.ex:51` — `GenServer.cast(__MODULE__, {:store, ...})`
- `lib/music_library_web/telemetry/storage.ex:56-69` — `handle_cast/2` runs `insert_and_prune/4` synchronously
- `lib/music_library_web/telemetry/storage.ex:89-107` — two SQLite queries per event: `INSERT` + `DELETE`-preserving-last-N subquery
- `TelemetryRepo` pool is 2 per `docs/production-infrastructure.md`, but the GenServer writes serially so pool size is irrelevant.
- `lib/music_library_web/telemetry/storage.ex:108-109, 125-126` — bare `catch _, _ -> :ok` swallows every error class including EXIT signals.

## Relation to #105

Issue #105 was closed as NOT_PLANNED with the rationale that bare catches are "reasonable for telemetry resilience". New framing: the catches mask a more fundamental design: the mailbox + synchronous-write pattern itself.

## Fix (options)

1. **Buffer-and-flush**: accumulate datapoints in-memory, flush batch every N seconds in a single transaction.
2. **Task.Supervisor per cast**: drain mailbox immediately, do I/O in a supervised task.
3. **ETS ring buffer + periodic flusher**: read path hits ETS; single-writer flusher persists to SQLite at a low cadence.

Whichever option is chosen, replace the bare `catch _, _` with either a targeted `rescue` or `Logger.debug` so failures become observable.

## Acceptance Criteria
<!-- AC:BEGIN -->
- Telemetry write path does not block on the GenServer mailbox
- Error path surfaces at least once per distinct failure (not silently swallowed)
- Existing dashboard queries continue to work
<!-- SECTION:DESCRIPTION:END -->

- [x] #1 Telemetry write path does not block on the GenServer mailbox
- [x] #2 Error path surfaces at least once per distinct failure (not silently swallowed)
- [x] #3 Existing dashboard queries continue to work
<!-- AC:END -->
