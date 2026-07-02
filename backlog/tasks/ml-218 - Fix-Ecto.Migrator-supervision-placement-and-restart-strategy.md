---
id: ML-218
title: Fix Ecto.Migrator supervision placement and restart strategy
status: To Do
assignee: []
created_date: "2026-06-10 10:40"
updated_date: "2026-06-10 10:57"
labels:
  - otp
  - fix
dependencies: []
references:
  - lib/music_library/application.ex
  - docs/architecture.md
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: low
ordinal: 51000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

In `MusicLibrary.Application` (lib/music_library/application.ex), the `Ecto.Migrator` child is listed after Oban and `MusicLibraryWeb.Telemetry`. In dev (where `skip: false`), Oban boots against the background DB before migrations run — this only works because setup scripts migrate beforehand; a fresh clone running `mix phx.server` directly would crash. The ordering communicates a dependency that doesn't exist.

Separately, under `one_for_one` a migration failure restarts the Migrator child, re-running the failing migration until the supervisor exhausts its restart intensity and takes down the whole app — noisy and misleading compared to a single clear failure.

Production is unaffected (`skip_migrations?/0` returns true in releases; Coolify runs migrations post-deploy).

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Ecto.Migrator is positioned immediately after the three repos and before Telemetry/Oban/Endpoint
- [ ] #2 Migrator child spec uses restart: :temporary so a failed migration produces one clear failure instead of a restart loop
- [ ] #3 App boots normally in dev and test; full test suite passes
- [ ] #4 docs/architecture.md supervision tree section updated to match the new ordering

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. In lib/music_library/application.ex, move the Ecto.Migrator entry to immediately after MusicLibrary.TelemetryRepo (before MusicLibraryWeb.Telemetry/PubSub/Oban).
2. Replace the bare tuple with an explicit child spec map setting `restart: :temporary`:
   `%{id: Ecto.Migrator, start: {Ecto.Migrator, :start_link, [[repos: ..., skip: skip_migrations?()]]}, restart: :temporary}` (verify Ecto.Migrator's child_spec supports the option directly first — `Supervisor.child_spec({Ecto.Migrator, opts}, restart: :temporary)` is the cleaner form).
3. Boot the app in dev (`mise run dev:console`) and run the full test suite to confirm startup ordering.
4. Update the supervision tree diagram in docs/architecture.md.
5. Run precommit.

<!-- SECTION:PLAN:END -->
