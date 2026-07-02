---
id: ML-204
title: Add SQLite constraints for enums and JSON fields
status: To Do
assignee: []
created_date: "2026-06-04 04:04"
updated_date: "2026-06-04 04:05"
labels:
  - sqlite
  - database
dependencies: []
references:
  - priv/repo/migrations/20260413090350_add_collection_entity_to_chats.exs
  - lib/music_library/records/record.ex
  - lib/music_library/scrobble_rules/scrobble_rule.ex
  - lib/music_library/chats/chat.ex
documentation:
  - "https://sqlite.org/changes.html#version_3_53_0"
  - "https://sqlite.org/lang_altertable.html"
  - docs/project-conventions.md
  - docs/architecture.md
modified_files:
  - priv/repo/migrations
  - lib/music_library/records/record.ex
  - lib/music_library/scrobble_rules/scrobble_rule.ex
  - lib/music_library/chats/chat.ex
  - test/music_library
  - docs/project-conventions.md
  - docs/architecture.md
priority: medium
ordinal: 37000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Use SQLite 3.53 ALTER TABLE constraint support to add database-level validation for high-value invariants that are currently enforced primarily by Ecto. The local database was checked and has no violations for likely enum targets (`records.type`, `records.format`, `scrobble_rules.type`, `chats.entity`) or common JSON validity/type checks. Add only constraints that are safe for existing production data and useful for preventing invalid writes.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 A new migration adds named CHECK and/or NOT NULL constraints for selected enum and JSON-shape invariants using SQLite 3.53-compatible ALTER TABLE syntax.
- [ ] #2 Every added constraint has a matching down migration path that removes the named constraint.
- [ ] #3 Constraint expressions match existing Ecto enum values and JSON field shape expectations exactly.
- [ ] #4 The migration accounts for existing data before adding constraints and avoids constraints that would fail production rows without a cleanup plan.
- [ ] #5 Tests verify representative invalid writes fail at the database boundary and valid writes continue to work.
- [ ] #6 Documentation or migration comments are updated so future work no longer assumes SQLite cannot alter CHECK/NOT NULL constraints.

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Confirm production-safe target constraints by querying existing data for enum violations, nullability violations, and invalid JSON/type mismatches.
2. Choose a minimal set of high-value constraints that match existing Ecto schemas and avoid risky historical-data assumptions.
3. Add a new migration using named SQLite 3.53 `ALTER TABLE ... ADD CONSTRAINT` and/or `ALTER COLUMN ... SET NOT NULL` statements, with explicit down statements.
4. Add tests that exercise representative database-boundary failures using direct inserts or changesets as appropriate.
5. Update comments/docs so future migrations no longer assume SQLite cannot alter CHECK/NOT NULL constraints.
6. Run migration/test checks on a migrated development database and verify down migration syntax.

<!-- SECTION:PLAN:END -->
