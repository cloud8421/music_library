---
id: ML-230
title: Fix prod-metrics pi extension crash
status: Done
assignee:
  - "@pi"
created_date: "2026-06-19 04:32"
updated_date: "2026-06-19 04:39"
labels: []
dependencies: []
references:
  - .pi/extensions/prod-metrics/index.ts
  - ML-229
ordinal: 61000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

The project-local prod-metrics pi extension currently crashes Pi during extension loading or command/tool registration. Diagnose the extension against the working extension patterns and pi extension API, fix the crash, and keep the existing production metrics tool and TUI behavior intact.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Pi can load the prod-metrics extension without crashing
- [x] #2 fetch_production_metrics_overview remains registered and handles missing env/API failures cleanly
- [x] #3 /prod-metrics remains registered for TUI mode and closes/cleans up without unhandled errors
- [x] #4 Existing prod-metrics extension tests and the project pi extension test runner pass or any remaining failures are documented
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Replace the unsupported prod-metrics command registration shape with the documented pi.registerCommand(name, { handler }) API used by the working extensions.
2. Rework /prod-metrics to use ctx.ui.custom with a MetricsBrowser component instead of ctx.openTui, preserving refresh/window/navigation/copy behavior and abort cleanup.
3. Add a regression test covering the command registration shape so registerCommand/openTui regressions are caught.
4. Run the prod-metrics tests and the project pi extension test runner.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Replaced unsupported pi.registerCommand object/execute registration with documented pi.registerCommand("prod-metrics", { handler }) shape. Reworked /prod-metrics command to render MetricsBrowser via ctx.ui.custom instead of ctx.openTui, with AbortController cleanup in finally and copy-to-editor support. Added a static regression test that rejects the removed openTui/object registration pattern.

Validation passed:

- cd .pi/extensions/prod-metrics && npm test (19 tests)
- mise run dev:pi-test
- PI_OFFLINE=1 pi --approve --offline --verbose --no-session --no-tools -e .pi/extensions/prod-metrics/index.ts -p "hello"
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Fixed the prod-metrics extension crash by replacing the unsupported object-shaped registerCommand/execute plus ctx.openTui usage with the documented pi.registerCommand("prod-metrics", { handler }) API and ctx.ui.custom rendering. The TUI still supports refresh, time-window switching, navigation, copy-to-editor, and abort cleanup. Added a regression test for the command registration shape. Verified with prod-metrics npm tests, mise run dev:pi-test, and a pi extension load smoke check.

<!-- SECTION:FINAL_SUMMARY:END -->
