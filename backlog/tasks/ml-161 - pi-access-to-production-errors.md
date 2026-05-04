---
id: ML-161
title: pi access to production errors
status: Done
assignee: []
created_date: '2026-05-04 08:06'
updated_date: '2026-05-04 13:18'
labels:
  - pi
  - api
dependencies:
  - ML-162
  - ML-163
  - ML-164
references:
  - 'backlog://document/doc-7'
priority: medium
ordinal: 9000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Errors in production are captured via the `error_tracker` Elixir dependency and accessed via a dedicated dashboard at `/dev/errors`. There is no built-in tooling or endpoint to pull production errors programmatically in a pi session. This task covers the investigation and implementation of the best approach to expose production error data to pi, broken into three subtasks:

1. **Expose production errors via a programmatic API (behind auth)** — Add a JSON API endpoint under `/api/v1/errors` that lists errors and shows individual error details from the error_tracker tables.
2. **Create pi tools to pull errors** — Implement `fetch_production_errors` (list with filtering/pagination) and `fetch_production_error` (single error detail) as pi tools.
3. **Create a pi extension to browse errors** — Build an interactive TUI browsing experience via a pi extension that uses the tools from subtask 2.

### Error data attributes

These are the attributes that subtask implementations must treat as the canonical data model:

**Error (from `error_tracker_errors` table):**
- `id` — UUID, unique error identifier
- `kind` — string, e.g. "error", "throw", "exit"
- `reason` — string, the error message/reason
- `source_line` — string, e.g. "lib/foo.ex:42"
- `source_function` — string, e.g. "MusicLibrary.Foo.bar/2"
- `status` — atom: `:resolved` | `:unresolved`
- `fingerprint` — hex string, deterministic hash of (kind, source_line, source_function)
- `last_occurrence_at` — UTC datetime (microsecond precision)
- `muted` — boolean
- `inserted_at` / `updated_at` — UTC datetime

**Occurrence (from `error_tracker_occurrences` table):**
- `id` — UUID
- `reason` — string, error reason at time of occurrence
- `context` — map, includes `live_view.view`, `request.path`, etc.
- `breadcrumbs` — array of strings
- `stacktrace` — embedded struct with `lines` array (each having: `application`, `module`, `function`, `arity`, `file`, `line`)
- `error_id` — FK to error
- `inserted_at` — UTC datetime

**Aggregated/per-error metadata (computed, not stored):**
- `occurrence_count` — total occurrences for this error
- `first_occurrence_at` — earliest occurrence timestamp
<!-- SECTION:DESCRIPTION:END -->
