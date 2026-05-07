---
id: ML-167
title: Improve Presto day-view scroll performance
status: Done
assignee: []
created_date: "2026-05-06 06:19"
updated_date: "2026-05-06 06:21"
labels:
  - presto
  - performance
dependencies: []
modified_files:
  - presto/records_on_the_day.py
priority: medium
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Optimize the Presto MicroPython records-on-this-day client so day-view scrolling feels snappier without changing the visible behavior. The current hot path repeatedly measures row text and computes scroll extents while dragging, and thumbnail fetching can still occur during drawing. Keep the existing placeholder-while-dragging behavior because decoding covers during drag was too slow on device.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Record display text, metadata, row height, and total scroll extent are prepared once when records are loaded or retried
- [x] #2 Micro cover images are prefetched and cached before rendering the day view when records load
- [x] #3 Drag scrolling redraws are throttled so display updates do not saturate the device
- [x] #4 Cover placeholders remain in use during active drag scrolling and real covers repaint after release
- [x] #5 Thumbnail rendering does not call garbage collection once per row draw
- [x] #6 README remains accurate if user-visible behavior changes
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Add a single record assignment/preparation path after each successful or failed day-record fetch.
2. Precompute display-safe title/artist strings, metadata text, row heights, thumbnail URL, and total content height before rendering the day view.
3. Preload only micro_cover_url thumbnails before the first draw to avoid eager large fallback downloads.
4. Keep placeholder rendering while dragging, remove per-row gc.collect from thumbnail drawing, and throttle drag redraws by time and pixel delta.
5. Verify with Python syntax compilation and leave README unchanged because behavior remains the same.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Implemented set_day_records/2, prepare_records_for_display/0, cached per-record \_display_title/\_display_artists/\_display_meta/\_thumb_url/\_row_height, cached \_content_height for max scroll offset, micro-thumbnail preloading, drag redraw throttling via DRAG_REDRAW_MS/DRAG_REDRAW_PX, and removed gc.collect from per-row thumbnail rendering. Cover placeholders remain during active drag and covers repaint after release.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Optimized the Presto day-view scroll path by moving text measurement, row height computation, content height calculation, and micro thumbnail fetches out of active scrolling. Drag redraws are now throttled and still use lightweight placeholders, with covers repainted after release. Verified syntax with py_compile.

<!-- SECTION:FINAL_SUMMARY:END -->
