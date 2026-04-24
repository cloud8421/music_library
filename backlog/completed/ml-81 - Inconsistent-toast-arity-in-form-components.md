---
id: ML-81
title: Inconsistent toast arity in form components
status: Done
assignee: []
created_date: '2026-04-20 08:57'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/94'
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-05 · updated 2026-03-05 · closed 2026-03-05_

## Priority: Medium

## Description

Form components (LiveComponents) should use `put_toast!/2` (arity 2), but most currently use `put_toast/3` (arity 3, intended for LiveViews):

**Using `put_toast/3` (incorrect for LiveComponents):**
- `lib/music_library_web/live/scrobble_rules_live/form.ex:97,112`
- `lib/music_library_web/live/online_store_template_live/form.ex:121,136`
- `lib/music_library_web/live/scrobbled_tracks_live/form.ex:113`
- `lib/music_library_web/live/artist_live/form.ex:271,303`

**Using `put_toast!/2` (correct):**
- `lib/music_library_web/live/record_set_live/form.ex:75,88`

## Expected behavior

All form components should use `put_toast!/2` consistently.

## Source

From technical debt audit (2026-03-05).
<!-- SECTION:DESCRIPTION:END -->
