---
id: ML-186
title: Improve Presto display redraw performance
status: Done
assignee:
  - Codex
created_date: "2026-05-16 20:14"
updated_date: "2026-05-16 20:22"
labels:
  - presto
  - performance
dependencies: []
references:
  - "https://github.com/pimoroni/presto/issues/56"
documentation:
  - "https://github.com/pimoroni/presto/blob/main/docs/presto.md"
modified_files:
  - presto/main.py
  - presto/tests/test_screens.py
priority: medium
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Use Pimoroni Presto partial display updates for bounded redraws in the MicroPython app where doing so preserves existing behavior. The current app performs full-screen updates for all draws; the desired outcome is to reduce display transfer work for high-frequency or small-area updates without changing visible UI behavior or making physical-device claims without on-device verification.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Bounded UI redraws use partial display updates when the Presto firmware supports them and safely fall back to full updates otherwise.
- [x] #2 Scrollable fixed-header views continue to render correctly during drag and release redraws.
- [x] #3 Search input and scrobble feedback preserve existing visible behavior while avoiding unnecessary full-screen display transfers where practical.
- [x] #4 Headless smoke tests pass, and any unverified physical-device behavior is clearly not claimed.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Add safe display update helpers in `presto/main.py`: a full update wrapper, a partial update wrapper with fallback, and named rectangles for the scroll viewport/search input/scrobble button.
2. Keep full-screen updates for full state transitions and broad redraws, but use partial updates for bounded areas where the buffer content can be refreshed independently.
3. For fixed-header scrollable views, add a bounded redraw mode that clears/redraws only the viewport below the header and calls `partial_update` for that region during drag redraws.
4. For small feedback updates, redraw only the search input field after query text changes and redraw only the scrobble button area when its state changes.
5. Add focused tests around fallback/partial-update behavior if the emulator can observe it, then run the Presto smoke test suite.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Implemented safe partial display update helpers with full-update fallback, viewport-only redraws for scrollable fixed-header views, query-field partial redraws, and scrobble-button partial redraws. After user correction, kept the detail cover layout at `DETAIL_COVER_SIZE = px(200)` and updated tests/docs that incorrectly described the cover as 460px.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Implemented bounded display update support for the Presto MicroPython app. Full-screen transitions still use full updates, while scroll redraws now refresh only the content viewport, search typing refreshes only the query field row, and scrobble loading/done feedback refreshes only the visible button region. Added tests for partial-update dispatch, fallback behavior, scroll viewport updates, search field updates, and scrobble button updates. Kept the detail cover layout at `DETAIL_COVER_SIZE = px(200)` and updated stale tests/docs that incorrectly described the detail cover as 460px.

Verification: `python3 -c "import py_compile; py_compile.compile('main.py', cfile='/tmp/main.pyc', doraise=True)"`; `python3 -m py_compile tests/test_screens.py`; `mise run test` (14 passed). Physical Presto behavior was not verified on-device.

<!-- SECTION:FINAL_SUMMARY:END -->
