---
id: ML-194
title: Add selective low-priority smoke coverage
status: To Do
assignee: []
created_date: "2026-05-20 17:19"
updated_date: "2026-05-20 17:20"
labels:
  - testing
  - coverage
dependencies: []
documentation:
  - docs/architecture.md
  - docs/project-conventions.md
  - docs/production-infrastructure.md
  - .agents/skills/testing/SKILL.md
  - .agents/skills/oban-worker/SKILL.md
  - .agents/skills/ui-framework/SKILL.md
priority: low
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Add only low-cost tests for low-coverage wiring where there is a real regression signal. This task should not chase percentages with brittle route enumeration, supervision-shape assertions, or Phoenix framework behavior. Focus on thin bulk worker delegation, timezone/static-asset hook assignment if practical, and browser CSP/header behavior.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Bulk cron worker smoke tests verify each all-record/all-artist worker delegates to the corresponding batch flow and enqueues the expected downstream jobs for representative records or artist infos.
- [ ] #2 The bulk worker tests avoid duplicating full single-item worker API refresh behavior that is already covered elsewhere.
- [ ] #3 A browser pipeline test asserts the Content-Security-Policy header includes the app-specific image, worker, connect, frame-ancestor, and base-uri directives that matter for current features.
- [ ] #4 GetTimezone hook coverage verifies a provided connect-param timezone is assigned and missing connect params fall back to MusicLibrary.default_timezone/0, if this can be tested without brittle framework setup.
- [ ] #5 StaticAssets hook coverage is added only if it can assert the assigned value through an existing LiveView request without coupling to Phoenix internals.
- [ ] #6 No tests are added for Application child ordering, exhaustive route enumeration, or framework-generated static_changed?/1 behavior unless a concrete project regression is identified.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Read docs/architecture.md, docs/project-conventions.md, docs/production-infrastructure.md, .agents/skills/testing/SKILL.md, and .agents/skills/oban-worker/SKILL.md before editing tests.
2. Add a small parameterized worker smoke test file for the all-record/all-artist workers, asserting the expected downstream enqueue behavior through existing batch flows.
3. Keep worker tests shallow: do not stub or exercise external API refresh behavior already covered by single-item worker tests.
4. Add a browser pipeline/controller test for the CSP header on a representative HTML route, asserting only directives that are project-specific and important to current features.
5. Investigate GetTimezone/StaticAssets hook coverage; add tests only if they can be expressed through stable public LiveView behavior without coupling to Phoenix internals.
6. Explicitly avoid Application child ordering, exhaustive route list, and framework static_changed?/1 tests.
7. Run the targeted worker/controller/hook tests and any affected web test file.
<!-- SECTION:PLAN:END -->
