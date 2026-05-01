---
id: ML-152
title: Add API version prefix to collection endpoints
status: Done
assignee: []
created_date: '2026-04-30 10:48'
updated_date: '2026-04-30 10:57'
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
- [x] #1 All collection API routes live under `/api/v1/collection/*`
- [x] #2 Existing `/api/collection/*` routes are removed or redirect to v1 with 301
- [x] #3 Controller and JSON tests pass against the new `/api/v1/` paths
- [x] #4 `test/prod.hurl` references updated to new paths
- [x] #5 `docs/architecture.md` updated with new route paths
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Implementation Plan

**Scope**: Version ALL routes under `/api` to `/api/v1/`, not just collection endpoints. Affected routes:
- `/api/v1/collection`
- `/api/v1/collection/latest`
- `/api/v1/collection/random`
- `/api/v1/collection/on_this_day`
- `/api/v1/assets/:transform_payload`
- `/api/v1/backup`

**Decision**: Remove old routes (no 301 redirects) — user controls all consumers.

**Files to change**:
1. `lib/music_library_web/router.ex` — Move all routes from `/api` to `/api/v1`
2. `test/music_library_web/controllers/collection_controller_test.exs` — Update paths to `/api/v1/collection/*`
3. `test/prod.hurl` — Update `/api/collection/latest` → `/api/v1/collection/latest`
4. `docs/architecture.md` — Update route table entries for CollectionController, AssetController (API route), ArchiveController (API route)
5. Asset controller tests (if any) — Check for `/api/assets/` references
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## Implementation complete

### Files changed

1. **`lib/music_library_web/router.ex`** — Changed `scope "/api"` to `scope "/api/v1"` for all 6 API routes (collection × 4 + assets + backup). Old routes removed per user decision.

2. **`lib/music_library_web/controllers/collection_json.ex`** — Updated `cover_url` and `thumb_url` path sigils from `~p"/api/assets/..."` to `~p"/api/v1/assets/..."`.

3. **`test/music_library_web/controllers/collection_controller_test.exs`** — Updated all 4 route paths, 4 describe strings, and 2 expected JSON URLs to `/api/v1/...`.

4. **`test/prod.hurl`** — Updated both API references from `/api/collection/latest` to `/api/v1/collection/latest`.

5. **`docs/architecture.md`** — Updated ArchiveController, AssetController, and CollectionController route entries to `/api/v1/...`.

### Test results
```
CollectionControllerTest: 5 passed
AssetControllerTest:      9 passed
ArchiveControllerTest:    1 passed
```
<!-- SECTION:NOTES:END -->
