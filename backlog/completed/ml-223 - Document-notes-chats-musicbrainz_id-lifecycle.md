---
id: ML-223
title: Document notes/chats musicbrainz_id lifecycle
status: Done
assignee:
  - pi
created_date: "2026-06-10 10:41"
updated_date: "2026-06-10 15:41"
labels:
  - docs
dependencies: []
references:
  - lib/music_library/notes.ex
  - lib/music_library/chats.ex
  - lib/music_library/records.ex
  - docs/architecture.md
  - backlog/docs/doc-34 - Architecture-Review-2026-06-10.md
priority: low
ordinal: 56000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

`Records.delete_record/1` prunes orphaned artist info but leaves the record's notes and chats in place. Because both are keyed by `musicbrainz_id` (not record FK), they also survive delete + re-import of the same record.

Maintainer decision (2026-06-10): this behaviour is **intentional** — notes and chats attach to the musical entity, not the database row. Documentation-only task: make the intent explicit so a future reviewer doesn't "fix" it as an orphaned-data bug (it was flagged as one in this review).

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Notes and Chats context @moduledoc explain that rows are keyed by musicbrainz_id and intentionally survive record deletion and re-import
- [x] #2 docs/architecture.md mentions the lifecycle in the relevant schema/context rows
- [x] #3 No behaviour change; full test suite passes

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Extend the @moduledoc of MusicLibrary.Notes and MusicLibrary.Chats: rows are keyed by entity + musicbrainz_id (no FK to records/artist_infos); they intentionally survive record deletion and re-import because they attach to the musical entity, not the database row.
2. Update docs/architecture.md: add the lifecycle note to the Notes/Chats rows of the schema or context tables (follow existing table style, keep it one factual sentence each).
3. Run precommit (docs prettier + elixir checks for the moduledoc changes).

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Extended @moduledoc in MusicLibrary.Notes and MusicLibrary.Chats to explain musicbrainz_id keying and intentional survival of record deletion/re-import.

Updated docs/architecture.md: added lifecycle notes to Notes.Note and Chats.Chat in Schemas table, and to Notes and Chats in Contexts table.

Precommit passed: all 1169 tests, prettier, credo, sobelow, gettext, deps.unlock, presto tests, Docker validation.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

Documented the intentional lifecycle of notes and chats relative to record deletion:

**Changes:**

- `lib/music_library/notes.ex` — Extended `@moduledoc` to explain that rows are keyed by `entity` + `musicbrainz_id` (no FK to records/artist_infos) and intentionally survive record deletion and re-import because they attach to the musical entity, not the database row.
- `lib/music_library/chats.ex` — Same `@moduledoc` extension for the Chats context.
- `docs/architecture.md` — Added lifecycle notes to four rows:
  - Schemas table: `Notes.Note` and `Chats.Chat` key fields now note "survives record deletion (no FK, keyed by musicbrainz_id)"
  - Contexts table: `Notes` and `Chats` responsibility descriptions now explain the musicbrainz_id keying and survival of record deletion

**Tests:** Full suite passes (1169 tests, 0 failures). All precommit gates pass (format, credo, sobelow, gettext, deps.unlock, prettier, presto, Docker validation).

**Risks/Follow-ups:** None. This is documentation-only — no behaviour changes.

<!-- SECTION:FINAL_SUMMARY:END -->
