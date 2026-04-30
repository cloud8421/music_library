---
id: ML-153
title: Move MusicBrainz data transformations out of Record schema
status: To Do
assignee: []
created_date: '2026-04-30 10:48'
labels:
  - refactor
  - records
  - musicbrainz
dependencies: []
references:
  - lib/music_library/records/record.ex
  - lib/music_brainz/release_group.ex
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The `Record` schema (`lib/music_library/records/record.ex`) contains MusicBrainz-specific data transformation functions that belong in the MusicBrainz API layer, not in the database schema:

- `parse_artists/1` — extracts artist credits from MusicBrainz API response
- `parse_subtype/2` / `parse_secondary_types/1` — maps MusicBrainz type strings to `Record` enum values
- `attrs_from_release_group/1` — builds a changeset attrs map from a MusicBrainz release group

These functions are called by `add_musicbrainz_data/2` (changeset pipeline) and during MusicBrainz import flows.

Move the parsing functions to appropriate `MusicBrainz` modules (e.g., `MusicBrainz.ReleaseGroup` already has related helpers) and keep only struct introspection/presentation functions on `Record` (`artist_names/1`, `releases/1`, `released?/1`, `format_release_date/1`, etc.).

Update callers in:
- `Record.changeset/2` and `add_musicbrainz_data/2`
- `Records` context (import functions)
- Any tests that reference the moved functions directly
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 `parse_artists/1`, `parse_subtype/2`, `parse_secondary_types/1`, and `attrs_from_release_group/1` are moved to `MusicBrainz` modules
- [ ] #2 `Record` schema retains only struct introspection and presentation helpers
- [ ] #3 All callers are updated to use the new locations
- [ ] #4 Full test suite passes
- [ ] #5 `@moduledoc` on moved functions explains their purpose
<!-- AC:END -->
