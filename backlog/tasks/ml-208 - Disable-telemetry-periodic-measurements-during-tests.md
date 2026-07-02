---
id: ML-208
title: Disable telemetry periodic measurements during tests
status: To Do
assignee: []
created_date: "2026-06-08 17:54"
labels:
  - testing
  - telemetry
dependencies: []
references:
  - lib/music_library_web/telemetry.ex
  - config/test.exs
  - config/config.exs
  - test/music_library_web/telemetry/storage_test.exs
documentation:
  - docs/architecture.md
modified_files:
  - lib/music_library_web/telemetry.ex
  - config/config.exs
  - config/test.exs
priority: medium
ordinal: 41000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Prevent background telemetry polling from running under the test environment when it is not required for test correctness. Current tests exercise telemetry storage directly rather than relying on periodic poller events, while the poller can query sandboxed repositories from its own process and produce ownership errors/noisy logs. Keep telemetry storage available for direct tests and dashboard wiring, but avoid periodic measurement processes during test runs.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Test runs do not start custom application telemetry periodic measurement polling.
- [ ] #2 Telemetry storage remains supervised and directly testable in the test environment.
- [ ] #3 Test runs do not start the telemetry_poller dependency's default VM poller unless explicitly required by a test.
- [ ] #4 Existing telemetry storage tests continue to pass without relying on periodic poller timing.
- [ ] #5 Running tests does not produce sandbox ownership errors from asset-size telemetry measurements.

<!-- AC:END -->
