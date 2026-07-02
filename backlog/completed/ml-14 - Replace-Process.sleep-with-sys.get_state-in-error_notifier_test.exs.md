---
id: ML-14
title: "Replace Process.sleep with :sys.get_state in error_notifier_test.exs"
status: Done
assignee: []
created_date: "2026-04-20 08:50"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/169"
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-04-16 · updated 2026-04-17 · closed 2026-04-17_

## Summary

Five `Process.sleep(50)` calls in `test/error_tracker/error_notifier_test.exs` wait for a GenServer to process a telemetry event before `assert_email_sent`. The sleeps are redundant and are the only timing-based waits in the suite.

## Evidence

`test/error_tracker/error_notifier_test.exs` lines: `:126`, `:136`, `:155`, `:164`, `:183`

Each call is after `:telemetry.execute/3`, waiting for the `ErrorTracker.ErrorNotifier` GenServer to process the cast and call the mailer.

## Fix

Replace each `Process.sleep(50)` with `:sys.get_state(ErrorTracker.ErrorNotifier)` — a synchronous probe that blocks until the GenServer has drained its mailbox up to the current message. Deterministic and faster.

## Acceptance Criteria

<!-- AC:BEGIN -->

- Zero `Process.sleep` occurrences in `test/`
- Tests remain deterministic and pass under repeated runs

<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Zero `Process.sleep` occurrences in `test/`
- [ ] #2 Tests remain deterministic and pass under repeated runs

<!-- AC:END -->
