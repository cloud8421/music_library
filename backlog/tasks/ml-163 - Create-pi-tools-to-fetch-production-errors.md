---
id: ML-163
title: Create pi tools to fetch production errors
status: To Do
assignee: []
created_date: '2026-05-04 08:08'
updated_date: '2026-05-04 08:18'
labels:
  - pi
dependencies: []
parent_task_id: DRAFT-1
priority: medium
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Create `fetch_production_errors` and `fetch_production_error` pi tools that call the `/api/v1/errors` JSON API endpoint.

These tools are registered via `pi.registerTool()` in a pi extension. They make authenticated HTTP requests to the production server using the same HURL variable pattern established by `fetch_production_logs` (ML-160).

### Tools

**`fetch_production_errors`** — List/filter production errors
- Parameters: `status` (optional: "resolved" | "unresolved"), `muted` (optional: boolean), `search` (optional: string, substring match on reason), `limit` (optional: number, default 50), `offset` (optional: number, default 0)
- Calls `GET /api/v1/errors` with query params
- Returns: formatted list of errors with counts and timestamps
- Truncates output with `truncateTail` (50KB / 2000 lines)

**`fetch_production_error`** — Get a single error with full details
- Parameters: `id` (required: UUID string)
- Calls `GET /api/v1/errors/:id`
- Returns: error details with all occurrences, stacktraces, and context
- Truncates output with `truncateTail`

### Tool guidelines (promptGuidelines)
- Use fetch_production_errors when investigating what errors are occurring in production
- Use fetch_production_error when you need full details on a specific error, including stacktraces and context
- Start with a small limit (e.g., 20) and filter by status or search before fetching large result sets

### Auth

Uses the same HURL variable pattern as `fetch_production_logs`:
- `PI_API_TOKEN` — Bearer token for API auth
- `PI_SERVICE_FQDN_WEB` — Production domain

They need to be configured in the pi environment as local secrets.
<!-- SECTION:DESCRIPTION:END -->
