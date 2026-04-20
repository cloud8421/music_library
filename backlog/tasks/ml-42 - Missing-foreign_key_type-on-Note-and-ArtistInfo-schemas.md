---
id: ML-42
title: Missing @foreign_key_type on Note and ArtistInfo schemas
status: Done
assignee: []
created_date: '2026-04-20 08:53'
labels: []
dependencies: []
references:
  - 'https://github.com/cloud8421/music_library/issues/135'
priority: low
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
_GitHub: created 2026-03-25 · updated 2026-03-25 · closed 2026-03-25_

## Description

Two schemas have `@primary_key {:id, :binary_id, autogenerate: true}` but are missing the corresponding `@foreign_key_type :binary_id` declaration:

- `MusicLibrary.Notes.Note` (`lib/music_library/notes/note.ex:6`)
- `MusicLibrary.Artists.ArtistInfo` (`lib/music_library/artists/artist_info.ex:9`)

All other binary_id schemas in the project correctly include both declarations. Neither schema currently has `belongs_to` associations that would be affected, but it breaks the established convention.

## Expected behavior

Add `@foreign_key_type :binary_id` after the `@primary_key` declaration in both schemas.

## Found during

Codebase consistency audit (2026-03-25)
<!-- SECTION:DESCRIPTION:END -->
