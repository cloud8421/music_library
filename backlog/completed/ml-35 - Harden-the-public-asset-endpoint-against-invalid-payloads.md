---
id: ML-35
title: Harden the public asset endpoint against invalid payloads
status: Done
assignee: []
created_date: "2026-04-20 08:52"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/143"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-30 · updated 2026-03-30 · closed 2026-03-30_

## Summary

The public asset endpoint uses bang-style decoding and hard matches during image transformation, so malformed payloads or transform failures can escape as 500s.

## Why This Matters

This endpoint is public and cacheable. Invalid user input should degrade to a controlled 400/404 response, not an exception. A corrupted or unsupported asset can also crash request handling.

## Evidence

- `AssetController.show/2` calls `Transform.decode!/1` on a path param.
- `cached_get/3` hard-matches `{:ok, image_data}` from image resize/convert operations.
- The current tests cover missing assets and valid transforms, but not malformed payloads or transform failures.

## Affected Files

- `lib/music_library_web/controllers/asset_controller.ex`
- `lib/music_library/assets/transform.ex`
- `lib/music_library/assets/image.ex`
- `test/music_library_web/controllers/asset_controller_test.exs`

## Suggested Fix

Handle invalid payloads and transform failures explicitly: replace bang-style decode with tuple-based validation in the controller boundary; convert failed image processing into a controlled 404/422/500 strategy; add regression tests for malformed payloads and failed conversion/resize paths.

## Acceptance Criteria

<!-- AC:BEGIN -->

- Invalid payloads do not raise from the controller.
- Failed image transforms do not crash the request path.
- Tests cover malformed payload and transform failure scenarios.
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Invalid payloads do not raise from the controller.
- [ ] #2 Failed image transforms do not crash the request path.
- [ ] #3 Tests cover malformed payload and transform failure scenarios.
<!-- AC:END -->
