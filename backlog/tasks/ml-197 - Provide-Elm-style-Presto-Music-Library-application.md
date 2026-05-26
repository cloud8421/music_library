---
id: ML-197
title: Provide Elm-style Presto Music Library application
status: In Progress
assignee:
  - Codex
created_date: "2026-05-26 05:39"
updated_date: "2026-05-26 05:43"
labels:
  - presto
dependencies: []
documentation:
  - presto/AGENTS.md
  - presto/README.md
  - presto/poc.py
  - presto/main.py
  - presto/tests/test_screens.py
  - presto/mise.toml
priority: medium
ordinal: 30000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Add an alternative Presto Music Library application organized around the message/update/view architecture demonstrated by the local proof of concept, while retaining the user-facing behavior of the existing device application.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 A `music_library.py` application exposes the existing Home, calendar/day browsing, search, record detail, scrobble, network error, and display sleep interactions through the Elm-style runtime.
- [ ] #2 Scrolling, cover loading, wake handling, and API request behavior remain consistent with the current Presto app constraints.
- [ ] #3 Headless verification covers the new application screens and prevents accidental network access during render tests.
- [ ] #4 User-facing or deployment documentation is updated if introducing the alternative application changes available usage or verification instructions.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Add a standalone `presto/music_library.py` entrypoint that remains deployable as device `main.py`, retaining the current screens, layout, API behavior, cached cover handling, scroll throttling, partial updates, and sleep/wake behavior.
2. Reshape application control flow around the POC contract: application model/runtime state, message constants, effect constants, pure state transitions in `update()`, hardware polling in `wire_events()`, effect execution in `run_effect()`, queued dispatch, and screen rendering in `render()`.
3. Keep network activity out of render hot paths in the new entrypoint, including routing initial detail-cover loading through an effect before detail rendering while using cached/placeholder imagery during drag redraws.
4. Extend emulator coverage for `music_library.py`, retaining the render/partial-update/image safety contracts and adding focused coverage of message/effect orchestration.
5. Add a deployment task for the architecture-based entrypoint and update `presto/README.md` with its optional deployment and verification path; no root architecture or production-infrastructure update is required because the API/default app contract is unchanged.
6. Verify with syntax compilation and `mise run test`; do not claim physical device behavior without hardware testing.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Read the project architecture, Presto guidance, README, project conventions, available task guidance, and testing skill before implementation. The change is scoped as one focused port with verification.

Inspected `presto/poc.py`, `presto/main.py`, test harness, and `presto/mise.toml`. The POC boundary is `Model`/`Runtime` plus messages, `update`, commands, `dispatch`, `run_effect`, and `render`; the current app invokes navigation/network/redraw directly in its polling loop. `main.py` also downloads the medium detail cover from drawing code, which should be preloaded by an effect in the new entrypoint to preserve a render-only view path. Existing smoke tests assert display regions, cover-size contracts, drag placeholders, and every visible screen.

User approved the implementation plan on 2026-05-26 and requested that this task record be committed before application work begins.

<!-- SECTION:NOTES:END -->
