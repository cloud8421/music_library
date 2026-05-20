---
id: ML-192
title: Add high-value behavioral test coverage
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
  - .agents/skills/testing/SKILL.md
  - .agents/skills/ui-framework/SKILL.md
  - .agents/skills/sqlite-optimization/SKILL.md
priority: high
ordinal: 35000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Increase coverage where current tests would catch meaningful regressions in user-facing workflows and core data transformations. Focus on the high-value gaps identified from the coverage triage: RecordForm genre and cover-search behavior, BarcodeScanner component state and import branches, Notes component create/update/read-edit behavior, ScrobbleRules subset application, and Assets.Image conversion/error handling. Avoid tests that only assert markup exists without exercising behavior.

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 Record editing tests cover genre search suggestions, adding a new normalized genre, preventing duplicate/blank genres, and removing an existing genre through the LiveComponent path.
- [ ] #2 Record editing tests cover Brave cover search success, search failure with a friendly message, selecting a search result, and persisting the downloaded cover hash on the record.
- [ ] #3 Barcode scanner tests cover a scan failure toast, removing one scanned result, clearing all scanned results, and the 2+ new-release async import branch including expected enqueued import jobs.
- [ ] #4 Notes component tests cover creating a new record or artist note, rendering an existing note in read mode, updating note content, and persisting the result through the Notes context.
- [ ] #5 Scrobble rules tests prove apply_all_rules/1 only updates the supplied track subset and leaves non-supplied matching tracks unchanged.
- [ ] #6 Assets image tests cover convert/3 same-format passthrough, successful JPEG/WebP conversion as supported by the app, and invalid image data returning an error tuple.
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

1. Read docs/architecture.md, docs/project-conventions.md, .agents/skills/testing/SKILL.md, and relevant UI/SQLite guidance before changing tests.
2. Add focused PhoenixTest/LiveView tests around existing record edit flows for genre events and cover search/download, stubbing BraveSearch.API and asserting persisted record state through MusicLibrary.Records.
3. Add BarcodeScanner tests through the collection scan LiveView or component harness, using Req.Test/Oban assertions to verify scan failure, remove/clear behavior, and async import enqueues.
4. Add Notes component coverage through record or artist show pages, asserting persisted notes through MusicLibrary.Notes rather than UI text alone.
5. Add ScrobbleRules subset tests with explicit scrobbled_at_uts values so only supplied tracks are updated.
6. Add Assets.Image tests for convert/3 and invalid data using existing image fixtures or fallback data.
7. Run targeted test files first, then run the relevant project test command if scope/time permits.
<!-- SECTION:PLAN:END -->
