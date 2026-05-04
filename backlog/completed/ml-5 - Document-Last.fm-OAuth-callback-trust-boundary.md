---
id: ML-5
title: Document Last.fm OAuth callback trust boundary
status: Done
assignee:
  - Claudio Ortolina
created_date: "2026-04-20 08:48"
updated_date: "2026-04-24 07:04"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/178"
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

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 last_fm_controller.ex has a comment documenting the trust boundary
- [x] #2 router.ex:55 notes the deliberate pipeline exemption
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan

1. **`lib/music_library_web/controllers/last_fm_controller.ex`** — add `@moduledoc` covering:
   - Why unauthenticated: OAuth redirect from Last.fm cannot carry session cookies across third-party redirect.
   - What protects it: Last.fm validates the `token` via `LastFm.get_session/1`; the call is rate-limited at the `Req` layer (`Req.RateLimiter`, 500ms/req); this is a single-user deployment.
   - Failure mode: invalid/forged tokens cause `get_session/1` to return `{:error, _}`; nothing is written to `secrets`, an error toast is shown, and the Req-layer error is logged.

2. **`lib/music_library_web/router.ex:55`** — add a brief comment above the route noting deliberate exemption from the `:logged_in` pipeline (with pointer to the controller moduledoc for details).

3. Run `mise run dev:precommit` to verify formatting, credo (including `ModuleDoc` rule), sobelow, and tests still pass.

## Notes

- Controllers are excluded from the `Credo.Check.Readability.ModuleDoc` regex in `.credo.exs`, so `@moduledoc` here is optional for lint purposes — using it is a deliberate choice for this security-sensitive module.
- No test changes required (documentation-only).
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## Summary

Documented the Last.fm OAuth callback trust boundary in two places:

- **`lib/music_library_web/controllers/last_fm_controller.ex`** — added `@moduledoc` explaining why the endpoint is unauthenticated (OAuth redirect from Last.fm cannot carry session cookies), what protects it (Last.fm-validated token, `Req.RateLimiter` bounding quota burn, single-user deployment), and the failure mode (invalid token → nothing stored, error toast shown).
- **`lib/music_library_web/router.ex`** — added a comment above the `/auth/last_fm/callback` route noting the deliberate exemption from the `:logged_in` pipeline, with a pointer to the controller moduledoc for the full trust boundary.

## Verification

`mise run dev:precommit` passes: credo, sobelow, format, translations, unused deps, and tests (827 passed, 43 doctests).

## Notes

Controllers are excluded from the `Credo.Check.Readability.ModuleDoc` regex in `.credo.exs`, so the `@moduledoc` here is a deliberate choice for a security-sensitive module, not a lint requirement.

<!-- SECTION:FINAL_SUMMARY:END -->
