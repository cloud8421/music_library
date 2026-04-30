---
id: ML-152
title: Add API version prefix to collection endpoints
status: To Do
assignee: []
created_date: '2026-04-30 10:48'
labels:
  - api
  - versioning
dependencies: []
references:
  - lib/music_library_web/router.ex
  - lib/music_library_web/controllers/collection_controller.ex
  - test/prod.hurl
priority: medium
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The JSON API endpoints under `/api/collection/*` (`lib/music_library_web/controllers/collection_controller.ex`) have no versioning prefix. If the response shape changes, external consumers would break without warning.

Add a `/api/v1/` prefix to all collection API routes:
- `/api/v1/collection`
- `/api/v1/collection/latest`
- `/api/v1/collection/random`
- `/api/v1/collection/on_this_day`

Keep existing routes as deprecated redirects (301) for backward compatibility, or remove them if there are no known consumers.

Update:
- `lib/music_library_web/router.ex` (route definitions)
- Controller and JSON tests
- `test/prod.hurl` (post-deploy verification that uses API endpoints)
- `docs/architecture.md` (API route table)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 All collection API routes live under `/api/v1/collection/*`
- [ ] #2 Existing `/api/collection/*` routes are removed or redirect to v1 with 301
- [ ] #3 Controller and JSON tests pass against the new `/api/v1/` paths
- [ ] #4 `test/prod.hurl` references updated to new paths
- [ ] #5 `docs/architecture.md` updated with new route paths
<!-- AC:END -->
