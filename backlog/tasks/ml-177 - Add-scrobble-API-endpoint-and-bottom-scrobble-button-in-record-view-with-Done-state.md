---
id: ML-177
title: >-
  Add POST /api/v1/collection/:record_id/scrobble endpoint and expose
  selected_release_id in API responses
status: To Do
assignee: []
created_date: "2026-05-10 18:46"
updated_date: "2026-05-10 19:19"
labels:
  - api
  - scrobble
  - backend
dependencies: []
references:
  - lib/music_library_web/router.ex
  - lib/music_library_web/controllers/collection_controller.ex
  - lib/music_library_web/controllers/collection_json.ex
  - lib/music_library/scrobble_activity.ex
  - presto/AGENTS.md
  - presto/main.py
  - >-
    backlog/tasks/ml-170 -
    Expose-additional-data-points-for-api-v1-collection-records.md
priority: medium
ordinal: 4000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Add a REST API endpoint `POST /api/v1/collection/:record_id/scrobble` that scrobbles the record's selected release to Last.fm, and expose `selected_release_id` in all collection API responses so the Presto device can determine whether a record is scrobbleable.

## Context

The [Pimoroni Presto](https://shop.pimoroni.com/products/presto) is a physical device running MicroPython (`presto/main.py`) that browses the music collection via the REST API. It needs a scrobble button in its record detail view (`STATE_RECORD` / `draw_record_detail()`). Since the Presto can only make HTTP requests (no WebSocket/LiveView), the scrobble action must be a REST endpoint.

The record view (`CollectionLive.Show`) in the web UI already has a scrobble button at the top (play icon in the button group) that uses a LiveView `phx-click` event — this task does NOT replace it.

## What this task covers (backend only)

1. **New route**: `POST /api/v1/collection/:record_id/scrobble` in the `:api` scope
2. **Controller action**: `CollectionController.scrobble/2` — looks up the record by ID, validates `selected_release_id` is present, fetches the release from MusicBrainz, calls `ScrobbleActivity.scrobble_release/3` with `:finished_at` and `DateTime.utc_now()`, returns JSON
3. **JSON response**: Success returns `%{status: "ok"}`, error returns `%{status: "error", reason: "..."}`
4. **Add `selected_release_id`** to the `CollectionJSON.record/1` response so the Presto can gate the scrobble button visibility (field is already on `SearchIndex`, just needs adding to the JSON map)
5. **Tests**: Controller test for the new endpoint (success, missing release_id, auth failure, MusicBrainz/Last.fm error cases)

## Out of scope

- No changes to the Presto app (`presto/main.py`) — that's a separate task
- No changes to the web UI LiveView
- No medium/track selection (entire-release scrobble only for this phase)
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [ ] #1 POST /api/v1/collection/:record_id/scrobble returns 200 with {"status": "ok"} when scrobble succeeds and the record has a selected_release_id
- [ ] #2 POST /api/v1/collection/:record_id/scrobble returns 422 with {"status": "error", "reason": "no_selected_release"} when the record has no selected_release_id
- [ ] #3 POST /api/v1/collection/:record_id/scrobble returns 401 when no valid Bearer token is provided
- [ ] #4 POST /api/v1/collection/:record_id/scrobble returns 404 when the record ID does not exist
- [ ] #5 All collection API responses (index, latest, random, on_this_day) include selected_release_id field (string or null)
- [ ] #6 Existing API response fields are unchanged (backward compatible)
- [ ] #7 Controller test covers success, missing release_id, missing record, auth failure, and Last.fm error cases
- [ ] #8 JSON view test verifies selected_release_id in record output
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan

### 1. Objective alignment

The Presto touch-screen device (`presto/main.py`) browses the collection via the REST API but cannot trigger a scrobble because the scrobble action is only available as a LiveView `phx-click` event on the web UI. This plan adds a REST endpoint `POST /api/v1/collection/:record_id/scrobble` that the Presto can call, gated by exposing `selected_release_id` in API responses so the device can conditionally show or hide the scrobble button.

### 2. Simplicity and alternatives considered

**Chosen approach**: Synchronous endpoint. `POST /api/v1/collection/:record_id/scrobble` performs an inline MusicBrainz API call followed by a Last.fm scrobble, all within the HTTP request cycle. The response is returned after the scrobble completes (or fails).

**Alternatives evaluated and rejected**:

- **Oban worker for async scrobble** — Decoupling via Oban would return `202 Accepted` immediately and let the Presto poll or use a webhook for the result. Rejected because: (a) the Presto has no persistent connection for polling/webhooks in its current design, (b) the MusicBrainz GET request is on the order of 200-500ms and the Last.fm POST is ~100-200ms, well within the render timeout, and (c) an immediate success/failure response is simpler for the Presto to handle (just parse JSON with `urequests`).

- **Dedicated JSON view module** (`CollectionJSON.scrobble/1`) — A separate view function for the response shape. Rejected because the response is trivial (`%{status: "ok"}` or `%{status: "error", reason: "..."}`) and doesn't warrant its own function; it's clearer to `json(conn, ...)` inline in the controller.

- **Scrobble via SearchIndex lookup** — Looking up the record via `SearchIndex` instead of `Record`. Rejected because `ScrobbleActivity.scrobble_release/3` needs a MusicBrainz API response (fetched fresh), not a DB struct. The `Record` lookup is only to validate existence and extract `selected_release_id`.

**Justification**: The synchronous approach is the simplest that meets the objective. The Presto workflow is user-initiated (tap button → wait for result), so sub-second latency is acceptable. If future requirements demand async (e.g., scrobbling large multi-disc releases with many tracks), an Oban-based approach can be layered on later without breaking the API contract.

### 3. Completeness and sequencing

The work comprises 4 steps with explicit dependencies:

#### Step 1: Add `selected_release_id` to `CollectionJSON.record/1`

**Why first**: This is the zero-risk change. It doesn't affect any existing consumer and doesn't depend on any other step. The Presto needs this field to decide whether to show the scrobble button.

- Add `selected_release_id: record.selected_release_id` to the map in `record/1` in `lib/music_library_web/controllers/collection_json.ex`.
- The field is already on `SearchIndex` (line 29 of `search_index.ex`) and is included by `essential_fields()` (which selects all `SearchIndex` fields). No database changes needed.

#### Step 2: Add the `POST /api/v1/collection/:record_id/scrobble` route

- Add `post "/collection/:record_id/scrobble", CollectionController, :scrobble` in the `:api` scope in `lib/music_library_web/router.ex`, immediately after the existing `/collection` routes.
- The route uses the `:api` pipeline which already applies `require_api_token`.

#### Step 3: Implement `CollectionController.scrobble/2`

- Add `scrobble/2` action to `lib/music_library_web/controllers/collection_controller.ex`.
- **Required aliases**: The controller currently only aliases `MusicLibrary.Collection`. For the scrobble action, you must also add:
  - `alias MusicLibrary.Records` — to call `Records.get_record!/1`
  - `alias MusicBrainz` — to call `MusicBrainz.get_release/1` (alternatively use the fully-qualified module name)
- Logic:
  1. Extract `record_id` from `conn.path_params`.
  2. Look up record via `MusicLibrary.Records.get_record!/1`; the `phoenix_ecto` library automatically converts raised `Ecto.NoResultsError` to a 404 response, so no explicit `case` is needed.
  3. Check `record.selected_release_id` is non-nil and non-blank; return 422 `%{status: "error", reason: "no_selected_release"}` if absent.
  4. Call `MusicBrainz.get_release(record.selected_release_id)` — returns `{:ok, release}` or `{:error, reason}`.
  5. On MusicBrainz error: return 502 `%{status: "error", reason: "musicbrainz_error"}`.
  6. Convert response: `MusicBrainz.Release.from_api_response(release)` → `release_with_tracks`.
  7. Call `ScrobbleActivity.scrobble_release(release_with_tracks, :finished_at, DateTime.utc_now())`.
  8. On success: return 200 `%{status: "ok"}`.
  9. On Last.fm error: return 502 `%{status: "error", reason: "lastfm_error"}`.
  10. On `ScrobbleActivity` returning `{:error, :no_duration}`: return 422 `%{status: "error", reason: "no_duration"}`.
  11. On `ScrobbleActivity` returning `{:error, :no_session_key}`: return 503 `%{status: "error", reason: "lastfm_not_configured"}`.

**Dependencies**: Steps 1 and 2 can be done in parallel; Step 3 depends on both.

#### Step 4: Write tests

- **Controller test** (`test/music_library_web/controllers/collection_controller_test.exs`):
  - Authentication: `POST /api/v1/collection/:id/scrobble` without Bearer token → 401.
  - Missing record: `POST` with valid token and non-existent ID → 404 (automatic via `phoenix_ecto`).
  - No selected release: `POST` with valid token and record without `selected_release_id` → 422 with `"no_selected_release"`.
  - Success: `POST` with valid token and record with `selected_release_id` → 200 with `%{"status" => "ok"}` (requires mocking `MusicBrainz.get_release/1` and `LastFm.scrobble/2`).
  - MusicBrainz error: `POST` with valid token, MusicBrainz returns error → 502.
  - Last.fm error: `POST` with valid token, MusicBrainz succeeds but Last.fm fails → 502.
  - No duration: `POST` where release has zero-duration tracks → 422.

- **JSON view**: Add `"selected_release_id"` assertion in `expected_record_json/1` in the existing controller test helper, and verify it's `null` when the record has no `selected_release_id`. **Note**: adding this field to `expected_record_json/1` will cause all existing view tests (latest, random, index, on_this_day) to fail until Step 1 code is applied. This is expected TDD behaviour — write the test assertion first, then implement the field in Step 1 to make all tests green again. The safest workflow is to add the field assertion and the code change together in Step 1, then verify with `mix test` that all tests pass before moving on.

**Dependencies**: Step 4 depends on Steps 1-3 being complete. Within Step 4, the JSON view assertion can be written as soon as Step 1 is done.

<!-- SECTION:PLAN:END -->
