---
id: ML-5
title: Document Last.fm OAuth callback trust boundary
status: To Do
assignee: []
created_date: '2026-04-20 08:48'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/178'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-16 · updated 2026-04-16_

## Summary

`GET /auth/last_fm/callback?token=X` is unauthenticated by design (OAuth flow requires it) but triggers storage of a session key in the encrypted secrets table. The trust model is not captured in comments, so future reviewers may re-flag it.

## Evidence

- `lib/music_library_web/controllers/last_fm_controller.ex:7`
- `lib/music_library_web/router.ex:55` (route outside `:logged_in` pipe)

Attack surface: cannot forge a valid token (Last.fm validates), but a malicious caller could consume `LastFm.get_session/1` rate-limit quota. Acceptable given the threat model.

## Fix

Add a short `@moduledoc` or inline comment in `last_fm_controller.ex` explaining:

1. Why this endpoint is unauthenticated (OAuth flow cannot carry session cookies across the Last.fm redirect)
2. What protects it (Last.fm-validated token, rate limiter, single-user scope)
3. What the failure modes look like (invalid token → store nothing, error logged)

Similarly in `router.ex:55`, a brief comment noting the deliberate exception from `:logged_in`.

## Acceptance Criteria
<!-- AC:BEGIN -->
- `last_fm_controller.ex` has a comment documenting the trust boundary
- `router.ex:55` notes the deliberate pipeline exemption
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 `last_fm_controller.ex` has a comment documenting the trust boundary
- [ ] #2 `router.ex:55` notes the deliberate pipeline exemption
<!-- AC:END -->
