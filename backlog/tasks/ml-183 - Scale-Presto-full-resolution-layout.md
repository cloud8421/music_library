---
id: ML-183
title: Scale Presto full-resolution layout
status: Done
assignee:
  - codex
created_date: "2026-05-15 07:01"
updated_date: "2026-05-15 07:19"
labels:
  - presto
dependencies: []
modified_files:
  - presto/main.py
  - presto/poc.py
  - presto/README.md
priority: medium
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Adjust the Presto MicroPython app after enabling full-resolution 480x480 mode so controls, spacing, and bitmap text render at approximately the same physical size they had in the default doubled-pixel mode.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 All hardcoded layout measurements in the Presto app are reviewed and scaled appropriately for full-resolution coordinates.
- [x] #2 Bitmap font scale values are reviewed and adjusted so visible text is not unexpectedly small after full_res=True.
- [x] #3 The app source passes the documented Python syntax check without writing **pycache**.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Scale fixed pixel constants in `presto/main.py` for full-resolution coordinates, using 2x values as the baseline and small fit adjustments where a strict double would push content offscreen.
2. Replace bitmap font scale usages in `presto/main.py` with named full-resolution scale constants so text returns to its prior physical size.
3. Apply the same full-resolution scaling to the small `presto/poc.py` proof-of-concept constants since it was also moved to `full_res=True`.
4. Re-scan for stale unscaled literals that affect layout or font rendering, then run the documented `py_compile` syntax check without creating `__pycache__`.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Scaled main Presto layout constants and bitmap font scale values for full-resolution coordinates. Calendar and keyboard use small fit adjustments from strict 2x values to avoid bottom overflow at 480x480. Row thumbnails now prefer the 150px mini cover source so 80px full-resolution row images do not render from a 40px micro image.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Scaled the Presto full-resolution UI so the move to `Presto(full_res=True)` keeps roughly the same physical sizing as the previous default doubled-pixel mode. `main.py` now uses named scale constants and a `px()` helper for layout measurements, font scales, row heights, scroll indicators, touch drag thresholds, headers, buttons, detail spacing, and keyboard geometry. Calendar cells and keyboard key height use small fit adjustments so their bottom rows stay within 480x480.

`poc.py` was scaled with the same 2x coordinate approach. The README thumbnail note was updated because row thumbnails now prefer `mini_cover_url`, avoiding 40px micro images inside the larger full-resolution row thumbnail box.

Verified with the documented `py_compile` syntax check for `main.py` and `poc.py`; no `__pycache__` output was written.

<!-- SECTION:FINAL_SUMMARY:END -->
