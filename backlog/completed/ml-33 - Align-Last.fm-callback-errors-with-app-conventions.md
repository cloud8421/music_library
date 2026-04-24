---
id: ML-33
title: Align Last.fm callback errors with app conventions
status: Done
assignee: []
created_date: '2026-04-20 08:52'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/145'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-30 · updated 2026-03-30 · closed 2026-03-30_

## Summary

The Last.fm OAuth callback bypasses the project's standard user-facing error handling and interpolates raw failure reasons directly into the flash message.

## Why This Matters

This is inconsistent with the documented convention for user-facing errors and increases the chance of exposing low-quality or overly-technical error text to users.

## Evidence

- `MusicLibraryWeb.LastFmController.callback/2` uses `put_toast(:error, "Failed to connect your Last.fm account: #{reason}")`.
- Project conventions say user-facing error reasons should go through `ErrorMessages.friendly_message/1` instead of raw inspection/interpolation.
- The current test only checks the flash prefix, so the inconsistency is not exercised.

## Affected Files

- `lib/music_library_web/controllers/last_fm_controller.ex`
- `docs/project-conventions.md`
- `test/music_library_web/controllers/last_fm_controller_test.exs`

## Suggested Fix

Align the controller with the established convention: keep the contextual prefix, translate the reason through `ErrorMessages.friendly_message/1`, ensure the resulting string remains wrapped appropriately for localization/user display.

## Acceptance Criteria
<!-- AC:BEGIN -->
- The Last.fm callback uses the same user-facing error formatting approach as the rest of the app.
- Tests assert the controller does not expose raw backend error terms in the flash.
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 The Last.fm callback uses the same user-facing error formatting approach as the rest of the app.
- [ ] #2 Tests assert the controller does not expose raw backend error terms in the flash.
<!-- AC:END -->
