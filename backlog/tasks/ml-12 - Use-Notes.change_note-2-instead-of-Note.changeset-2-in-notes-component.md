---
id: ML-12
title: Use Notes.change_note/2 instead of Note.changeset/2 in notes component
status: Done
assignee: []
created_date: '2026-04-20 08:49'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/171'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-04-16 · updated 2026-04-17 · closed 2026-04-17_

## Summary

`lib/music_library_web/components/notes.ex` calls `Note.changeset/2` directly at three sites, bypassing the context helper `MusicLibrary.Notes.change_note/2` (which already exists and is used at line 97 of the same component).

## Evidence

- `lib/music_library_web/components/notes.ex:15`
- `lib/music_library_web/components/notes.ex:121`
- `lib/music_library_web/components/notes.ex:138`

All three could call `Notes.change_note(note, %{})` instead.

## Why It Matters

The "LiveViews / LiveComponents call the context, not schema modules" boundary is load-bearing in this project. The component already honours it at line 97 — these three spots are the outliers.

## Fix

Mechanical find-and-replace. Three one-line edits.

## Acceptance Criteria
<!-- AC:BEGIN -->
- Tests still pass
- No direct `Note.changeset` references in `lib/music_library_web/components/notes.ex`
<!-- SECTION:DESCRIPTION:END -->

- [ ] #1 Tests still pass
- [ ] #2 No direct `Note.changeset` references in `lib/music_library_web/components/notes.ex`
<!-- AC:END -->
