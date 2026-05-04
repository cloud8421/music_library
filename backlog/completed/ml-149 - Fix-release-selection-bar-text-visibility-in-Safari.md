---
id: ML-149
title: Fix release selection bar text visibility in Safari
status: Done
assignee:
  - Codex
created_date: "2026-04-30 06:11"
updated_date: "2026-04-30 06:20"
labels:
  - bug
  - ui
dependencies: []
references:
  - lib/music_library_web/components/release.ex
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

When multiple tracks are selected in the release UI, the `selection_bar` component should show its left-hand selection text consistently across supported browsers. The current behavior shows the text in Chrome but leaves it invisible in Safari.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 The left-hand selection text is visible in Safari when multiple tracks are selected.
- [x] #2 The existing Chrome rendering remains unchanged or visually equivalent.
- [x] #3 The fix is scoped to the release selection bar and does not alter unrelated release controls.
- [x] #4 Relevant formatting and focused verification are run or any inability to run them is documented.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Read the project conventions and inspect `lib/music_library_web/components/release.ex` plus nearby CSS/assets that affect `selection_bar`.
2. Identify the Safari-specific style interaction causing the left selection text to be invisible when multiple tracks are selected.
3. Apply the smallest scoped change to the release selection bar so the text remains visible in Safari while preserving Chrome rendering.
4. Run formatting and focused verification, then update acceptance criteria and final notes.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Changed the selection bar wrapper from the non-existent `isolated` class to Tailwind's `isolate` utility, giving the sticky bar an explicit `isolation: isolate` stacking context. This is scoped to `lib/music_library_web/components/release.ex` and targets Safari's sticky/composited paint issue where the left summary text was not visible. Ran `mix format lib/music_library_web/components/release.ex` and `mix test test/music_library_web/components/release_test.exs` successfully. Manual Safari browser verification was not available in this environment.

User reported that changing `isolated` to `isolate` did not fix the Safari visibility issue. Reopened the task for further investigation.

Applied a second scoped patch after the first attempt failed: the sticky selection bar now uses `transform-gpu` to force a composited layer in WebKit, and the left text block uses `relative z-10 flex-auto` instead of `flex-1` so Safari has an explicit paint/layer order and content-based flex basis. `mix format lib/music_library_web/components/release.ex` and `mix test test/music_library_web/components/release_test.exs` both pass. Waiting for user confirmation before checking the Safari acceptance criteria or closing the task.

User isolated the fix in Safari: `relative` on the selection bar's left text container fixes the invisible text. The earlier `isolate`, `transform-gpu`, `z-10`, and `flex-auto` changes were unnecessary and have been removed. The final code change is only `relative` on the existing `min-w-0 flex-1 leading-tight` container. Ran `mix format lib/music_library_web/components/release.ex` and `mix test test/music_library_web/components/release_test.exs` successfully.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Added `relative` to the left text container inside the release `selection_bar`. Safari was failing to visibly paint that text when tracks were selected; the positioned container fixes the rendering issue without changing the selection bar layout, colors, or actions.

Verification:

- User confirmed in Safari that `relative` is the change that fixes the issue.
- `mix format lib/music_library_web/components/release.ex`
- `mix test test/music_library_web/components/release_test.exs`
<!-- SECTION:FINAL_SUMMARY:END -->
