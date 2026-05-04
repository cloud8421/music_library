---
id: ML-162
title: Expose production errors via JSON API endpoint
status: To Do
assignee: []
created_date: '2026-05-04 08:08'
updated_date: '2026-05-04 08:19'
labels:
  - api
dependencies: []
parent_task_id: DRAFT-1
priority: medium
ordinal: 7000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Add an API controller and routes under `/api/v1/errors` to expose ErrorTracker data as JSON, behind the existing Bearer token auth.

This subtask covers the server-side work only: controller, JSON serialization, context queries, and routes. The pi tooling and extensions are covered by separate subtasks.

### API design

**`GET /api/v1/errors`** — List errors
- Query params: `status` (resolved/unresolved), `muted` (true/false), `search` (substring match on reason), `limit` (default 50), `offset` (default 0)
- Returns: `{ errors: [...], total: n, limit: n, offset: n }`
- Each error includes: id, kind, reason, source_line, source_function, status, fingerprint, last_occurrence_at, muted, inserted_at, updated_at, occurrence_count, first_occurrence_at

**`GET /api/v1/errors/:id`** — Single error detail
- Returns the error with all its occurrences (with stacktraces), sorted by inserted_at desc
- Each occurrence includes: id, reason, context, breadcrumbs, stacktrace (lines), inserted_at

### Data attributes (canonical — shared with all subtasks)

**Error fields:** id, kind, reason, source_line, source_function, status, fingerprint, last_occurrence_at, muted, inserted_at, updated_at
**Occurrence fields:** id, reason, context, breadcrumbs, stacktrace (with lines), error_id, inserted_at
**Computed:** occurrence_count, first_occurrence_at

### Dependencies

- Uses `MusicLibrary.TelemetryRepo` (already exists)
- Uses the `error_tracker_errors` and `error_tracker_occurrences` tables (already exist)
- Auth via existing `require_api_token` plug (already in use by `/api/v1` pipeline)
<!-- SECTION:DESCRIPTION:END -->
