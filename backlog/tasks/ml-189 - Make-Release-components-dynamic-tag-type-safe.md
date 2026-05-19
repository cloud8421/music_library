---
id: ML-189
title: Make Release component's dynamic tag type-safe
status: To Do
assignee: []
created_date: "2026-05-19 08:42"
labels:
  - audit
  - liveview
  - components
  - type-safety
dependencies: []
documentation:
  - >-
    audits/phase1-async-message-coverage/doc-24 -
    Audit-Report-LiveComponent-→-Parent-handle_info-Coverage-Phase-1.md
modified_files:
  - lib/music_library_web/components/release.ex
  - lib/music_library_web/live/scrobble_live/release_show.ex
priority: low
ordinal: 24000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

The Release component (lib/music_library_web/components/release.ex:82) uses `send(self(), {tag, release})` where `tag` is a dynamic assign (`on_release_loaded`). While correctly handled today, if a future consumer sets a non-atom tag, pattern matching in `handle_info` would fail silently since clauses match on atoms like `:release_loaded`.

**Fix:** Change to `send(self(), {__MODULE__, {:loaded, release}})` with a static atom, making the message self-documenting and type-safe.

**Source:** Audit doc-24 (Phase 1), Recommendation #1.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Release component sends {**MODULE**, {:loaded, release}} instead of {tag, release}
- [ ] #2 ScrobbleLive.ReleaseShow handle_info updated to match new message shape
- [ ] #3 CollectionLive.Show still works correctly (no message sent when on_release_loaded is nil)
<!-- AC:END -->
