---
id: ML-179
title: Refactor Presto main.py state handling
status: Done
assignee:
  - Codex
created_date: "2026-05-10 20:11"
updated_date: "2026-05-10 20:19"
labels: []
dependencies: []
documentation:
  - presto/AGENTS.md
  - presto/README.md
  - docs/project-conventions.md
modified_files:
  - presto/main.py
priority: medium
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Refactor presto/main.py in a single-file, behavior-preserving pass to reduce scattered global state, centralize navigation/reset rules, and remove duplicated scroll gesture logic. Keep deployment as one main.py file for the Pimoroni Presto app.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 presto/main.py keeps hardware objects, constants, layout values, color pens, and pure helpers at module level while moving mutable view state into simple MicroPython-compatible holder classes.
- [x] #2 Stateful functions accept an AppState instance and access state through grouped fields instead of mutable module globals, with behavior preserved across home, search, month, day, detail, display sleep, and scrobble flows.
- [x] #3 Navigation helper functions centralize screen transitions and reset the correct per-view scroll, loading, error, keyboard, detail, and scrobble state.
- [x] #4 Record-list preparation returns content height for the caller to assign to day or search state while preserving existing per-record display cache keys.
- [x] #5 Shared vertical drag handling replaces duplicated day, search, and detail drag loops without fetching images or measuring layout in the drag hot path.
- [x] #6 Syntax verification passes from presto/ with python3 py_compile and final notes state that physical-device behavior was not verified unless tested on hardware.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Add simple AppState, DayListState, SearchState, DetailState, and TouchState classes near the current global state section and initialize grouped mutable state through AppState.
2. Convert stateful startup, display sleep, API, draw, hit-test, and touch handler functions to accept app and read/write app.<group>.<field> instead of module-level mutable globals.
3. Add navigation helpers for home, today/month, day, detail, back-from-detail, search input, and search results transitions; use them for all screen changes so scroll/error/loading/detail/scrobble resets are centralized.
4. Replace prepare_records_for_display/1 with prepare_record_list(recs), returning content height while preserving record dict cache keys and thumbnail preloading behavior.
5. Extract the duplicated vertical drag loop into a shared helper parameterized by offset getters/setters, max offset, redraw callback, and placeholder-during-drag behavior.
6. Run the Presto syntax check from presto/ and update the task acceptance criteria/final notes based on verification.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Implemented the refactor in presto/main.py as a single-file change. Mutable app state now lives under AppState and grouped state holders. Navigation helpers own the screen transitions and reset rules. Record-list preparation now returns content height for the caller. The repeated day/search/detail scroll loops were replaced by handle_vertical_drag, and detail cover drawing avoids thumbnail fetches while drag redraws are active. Verification run: python3 py_compile from presto/ passed; git diff --check passed. Physical Presto hardware behavior was not verified.

Follow-up tightening before final response: cached wrapped row lines and detail line metrics so drag redraws can reuse prepared layout data. Re-ran python3 py_compile from presto/ and git diff --check; both passed.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Refactored presto/main.py to group mutable runtime state under AppState while leaving hardware handles, constants, layout values, pens, and pure helpers at module scope. Added navigation helpers for home, today/month, day loading, record detail, detail back navigation, search input, and search results so view-entry reset behavior is centralized.

Converted stateful drawing, API, display sleep, hit-test, and touch handler paths to accept the AppState instance. Replaced prepare_records_for_display with prepare_record_list returning content height for day/search callers, preserving the existing record display cache keys and adding prepared wrapped-line caches for drag redraw performance. Replaced duplicated day, search, and detail drag loops with handle_vertical_drag and kept image fetching out of drag redraws by using placeholders where needed.

Verification: python3 py_compile passed from presto/ with cfile=/tmp/main.pyc, and git diff --check passed. Physical-device behavior was not verified on the Presto hardware.

<!-- SECTION:FINAL_SUMMARY:END -->
