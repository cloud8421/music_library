---
id: ML-61
title: Standardize dropdown toggle variant across pages
status: Done
assignee: []
created_date: "2026-04-20 08:54"
labels: []
dependencies: []
references:
  - "https://github.com/cloud8421/music_library/issues/114"
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

_GitHub: created 2026-03-16 · updated 2026-03-16 · closed 2026-03-16_

## Problem

Show pages use `variant="soft"` for dropdown toggle buttons while index pages use `variant="ghost"`. This may be intentional (different contexts) or accidental drift.

**Show pages (`variant="soft"`):** `collection_live/show.ex:90`, `wishlist_live/show.ex:57`, `artist_live/show.ex:138`, `record_set_live/show.ex:28`

**Index pages (`variant="ghost"`):** `scrobble_rules_live/index.ex:113`, `online_store_template_live/index.ex:65`, `scrobbled_tracks_live/index.ex:160`

## Decision needed

Pick one variant for all action dropdown toggles, or document the show/index distinction as intentional.

<!-- SECTION:DESCRIPTION:END -->
