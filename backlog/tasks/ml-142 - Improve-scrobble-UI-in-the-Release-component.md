---
id: ML-142
title: Improve scrobble UI in the Release component
status: To Do
assignee: []
created_date: '2026-04-20 09:32'
updated_date: '2026-04-20 09:35'
labels:
  - ui
  - scrobble
dependencies: []
references:
  - lib/music_library_web/live/components/release.ex
  - lib/music_library_web/components/scrobble_components.ex
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Release component's scrobble interface has several usability gaps that make scrobbling cumbersome, especially for multi-medium releases. This task improves the experience across three areas: custom scrobble time, button visual clarity, and per-medium scrobble access.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Users can set a custom `finished_at` datetime before scrobbling, defaulting to the current time when not set
- [ ] #2 Scrobble buttons have sufficient contrast in both their enabled and disabled states so users can clearly distinguish between the two
- [ ] #3 Enable scrobbling of selected tracks from the closest scrabble button (i.e. the medium button) instead of always having to scrobble to the top one.
<!-- AC:END -->
