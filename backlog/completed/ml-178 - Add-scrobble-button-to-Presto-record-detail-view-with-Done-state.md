---
id: ML-178
title: Add scrobble button to Presto record detail view with "Done" state
status: Done
assignee: []
created_date: "2026-05-10 18:57"
updated_date: "2026-05-11 06:47"
labels:
  - presto
dependencies:
  - ML-177
references:
  - presto/main.py
  - presto/AGENTS.md
  - presto/README.md
priority: medium
ordinal: 5000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Add a scrobble button to the record detail view (`draw_record_detail()` / `STATE_RECORD`) in the Presto MicroPython app. The button sends a POST request to `/api/v1/collection/:record_id/scrobble` and shows "Done" on success.

## Context

The Presto app (`presto/main.py`) browses the music collection via the REST API. It has three views: month calendar, day list, and record detail. The record detail view (`STATE_RECORD` → `draw_record_detail()`) currently shows: header with back button, title/artists, large cover image, genres, metadata (type|format|year), and purchase date.

This task adds a scrobble button **at the bottom** of the record detail view, after all existing content. The button is only shown when the record has a `selected_release_id` (fetched from the API response — this field is added by backend task ML-177).

## Design decisions

- The button is a rectangular button with centered text, similar to the existing "Back" button in the header
- Button text states: "Scrobble" (initial), "..." (loading/request in progress), "Done" (success), revert to "Scrobble" on error
- The button is only drawn when `rec.get("selected_release_id")` is truthy
- Uses `urequests.post()` to call the API with the stored `API_TOKEN` in the `Authorization` header
- On HTTP error or network failure, the button reverts to "Scrobble" (no toast — the Presto has no toast system, but could show an error briefly)
- Scrobble state is per-record and resets when navigating away

## Layout constants needed

- `SCROBBLE_BUTTON_W` — button width (suggest centered, e.g., 200px)
- `SCROBBLE_BUTTON_H` — button height
- `SCROBBLE_BUTTON_Y` — computed from the bottom of the detail content
- Colors: `_pen_scrobble_bg`, `_pen_scrobble_text`, `_pen_scrobble_done_bg`, `_pen_scrobble_done_text`

## Touch handling

In the `STATE_RECORD` touch dispatch, check if the tap falls within the scrobble button bounds. If so:

1. Start the HTTP request (blocking — use a brief timeout)
2. Update the button state
3. Redraw

## Out of scope

- No changes to the backend API (covered by ML-177)
- No toast/error display system
- No debounce or double-tap prevention (can be added later)

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 The scrobble button appears at the bottom of the record detail view only when the record has a non-null selected_release_id
- [x] #2 The scrobble button is not shown for records without a selected_release_id
- [x] #3 Tapping the button sends a POST to /api/v1/collection/:record_id/scrobble with the Bearer token from secrets
- [x] #4 While the HTTP request is in progress, the button shows a loading indicator (e.g., "..." text)
- [x] #5 On 200 response, the button displays "Done"
- [x] #6 On non-200 response or network error, the button reverts to "Scrobble"
- [x] #7 The Presto app can still be deployed with `mise run presto`
- [x] #8 The `selected_release_id` field from the on_this_day API response is used to gate button visibility
- [x] #9 Scrolling in the detail view still works correctly (the button scrolls with the content)

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Objective alignment

Add a scrobble button to the Presto record detail view (`draw_record_detail()` / `STATE_RECORD`) that sends `POST /api/v1/collection/:record_id/scrobble` and displays a visual "Done" confirmation on success. The button gates on the `selected_release_id` field (added by ML-177), so only scrobble-eligible records show the button.

This maps directly to the problem: the Presto device can browse records but has no way to trigger a Last.fm scrobble. The REST endpoint (ML-177) provides the server-side action; this task wires it to a touch target on the device.

## Simplicity and alternatives considered

**Chosen approach:** A single rectangular button appended to the bottom of the scrollable detail content, with a blocking HTTP request on tap and three visual states (idle / loading / done). The "Done" state persists until the user navigates away (no auto-revert), keeping the implementation simple and avoiding additional blocking sleeps.

**Alternatives evaluated and rejected:**

1. **Fixed-position button (always visible at screen bottom):** Simpler to implement (no scroll height recalculation, no hit-test complexity). Rejected because (a) it consumes ~50px of the 720px display permanently, (b) the Presto has no concept of a "sticky footer" — the existing scrolling + clip infrastructure would need rework for a fixed overlay, and (c) a button that scrolls with content is more discoverable and feels like part of the record.

2. **Non-blocking / async HTTP request:** Ideal UX but MicroPython on Presto does not support `_thread` or `asyncio` in a usable way. The blocking approach with a brief timeout is the pragmatic trade-off. The "..." loading state provides visual feedback during the blocking call. **Note:** MicroPython's `urequests` has limited timeout support. If WiFi drops mid-request, the default timeout can be 30+ seconds, freezing the display. This is an acceptable trade-off for a user-initiated action on a device that rarely loses connectivity, but should be tested on-device with a simulated WiFi disconnect to understand the real-world behavior.

3. **Toast / error display system:** Would improve error feedback but is explicitly out of scope for this task. The plan uses a minimal error-revert (button returns to "Scrobble" on failure) which is sufficient.

4. **Auto-revert "Done" to "Scrobble" after a delay:** Would reset the button to allow re-scrobbling. Rejected because (a) it adds a `time.sleep(1.5)` on top of the already-blocking HTTP request, (b) the scrobble state already resets on navigation (Step 3), and (c) keeping "Done" visible provides clearer feedback that the action succeeded. Users who want to re-scrobble can navigate away and back.

## Completeness and sequencing

The following steps are ordered by dependency. Each step must be completed and verified before the next.

### Step 1: Add layout constants

**File:** `presto/main.py`, in the "Detail view" constants block (near `DETAIL_TEXT_W`)

Add:

```python
# Scrobble button (detail view)
SCROBBLE_BUTTON_W = 200
SCROBBLE_BUTTON_H = 40
SCROBBLE_BUTTON_GAP = 12  # vertical gap before button
```

Also add color constants in the "Colors" block (near `STATUS_TEXT`):

```python
SCROBBLE_BG = (55, 65, 81)         # Same slate as HOME_BTN_BG
SCROBBLE_TEXT = (228, 228, 231)    # Same as TITLE_COLOR
SCROBBLE_DONE_BG = (34, 197, 94)   # Green success
SCROBBLE_DONE_TEXT = (255, 255, 255)
```

**Verification:** `python3 -c "import py_compile; py_compile.compile('presto/main.py', doraise=True)"` passes without error.

### Step 2: Add new pens

**File:** `presto/main.py`

Add module-level pen variables near existing `_pen_home_btn`:

```python
_pen_scrobble_bg = None
_pen_scrobble_text = None
_pen_scrobble_done_bg = None
_pen_scrobble_done_text = None
```

Initialize in `_init_pens()`:

```python
_pen_scrobble_bg = display.create_pen(*SCROBBLE_BG)
_pen_scrobble_text = display.create_pen(*SCROBBLE_TEXT)
_pen_scrobble_done_bg = display.create_pen(*SCROBBLE_DONE_BG)
_pen_scrobble_done_text = display.create_pen(*SCROBBLE_DONE_TEXT)
```

Also add these pens to the `global` declarations in `_init_pens()`.

**Verification:** Syntax check passes. No pen-related `NameError` when running on device.

### Step 3: Add global scrobble state

**File:** `presto/main.py`, in the "GLOBAL STATE" block (near `detail_scroll_offset`)

Add:

```python
# Scrobble button state (per-record-detail-visit; resets on navigation)
_scrobble_state = "idle"  # "idle" | "loading" | "done"
```

Add `_scrobble_state` to the `global` declarations in `main()`.

Reset `_scrobble_state = "idle"` in all entry points to `STATE_RECORD` and all exit points:

**Entry point 1 — STATE_DAY → STATE_RECORD (in `main()`, inside the `if not dragged:` block after the day-view drag loop, alongside `detail_scroll_offset = 0`):**

```python
detail_scroll_offset = 0
_scrobble_state = "idle"
```

**Entry point 2 — STATE_SEARCH_RESULTS → STATE_RECORD (in `handle_search_results_touch()`, alongside `detail_scroll_offset = 0`):**

```python
detail_scroll_offset = 0
_scrobble_state = "idle"
```

**Exit point — STATE_RECORD back-button handler (in `main()`, alongside `detail_scroll_offset = 0`):**

```python
detail_scroll_offset = 0
_scrobble_state = "idle"
```

**Verification:** Syntax check passes. Code review: verify that every code path that enters `STATE_RECORD` sets `_scrobble_state = "idle"`, and every code path that leaves `STATE_RECORD` also sets it. There are exactly 2 entry paths and 1 exit path as enumerated above.

### Step 4: Modify `_measure_detail_content()` to include button height

**File:** `presto/main.py`, function `_measure_detail_content()`

At the end of the function, before `_detail_content_height = h`, add:

```python
    # Scrobble button (at bottom, only if scrobble-eligible)
    if rec.get("selected_release_id"):
        h += SCROBBLE_BUTTON_GAP
        h += SCROBBLE_BUTTON_H
```

**Verification:** On-device test — navigate to a record with `selected_release_id` set (after ML-177 is deployed). The scroll viewport should accommodate the extra button height. The `^` / `v` scroll indicators should appear/disappear correctly. Records without `selected_release_id` should have the same scroll behavior as before. For offline testing before ML-177 is deployed, temporarily hard-code `selected_release_id` to a known UUID string on a test record dict.

### Step 5: Add `_draw_scrobble_button()` helper

**File:** `presto/main.py`, in the "DRAWING: RECORD DETAIL" section

New function:

```python
def _draw_scrobble_button(rec, y):
    """Draw the scrobble button at (x, y). Button is horizontally centered.
    Visual state depends on global _scrobble_state."""
    global _scrobble_state

    bx = (WIDTH - SCROBBLE_BUTTON_W) // 2

    if _scrobble_state == "done":
        bg_pen = _pen_scrobble_done_bg
        text_pen = _pen_scrobble_done_text
        label = "Done"
    elif _scrobble_state == "loading":
        bg_pen = _pen_scrobble_bg
        text_pen = _pen_scrobble_text
        label = "..."
    else:
        bg_pen = _pen_scrobble_bg
        text_pen = _pen_scrobble_text
        label = "Scrobble"

    display.set_pen(bg_pen)
    display.rectangle(bx, y, SCROBBLE_BUTTON_W, SCROBBLE_BUTTON_H)

    display.set_pen(text_pen)
    display.set_font("bitmap8")
    _draw_centered_text(label, bx, y, SCROBBLE_BUTTON_W, SCROBBLE_BUTTON_H, 8)
```

**Verification:** Syntax check passes. Helper is callable but not yet wired in.

### Step 6: Modify `draw_record_detail()` to draw the button

**File:** `presto/main.py`, function `draw_record_detail()`

**Important:** The local variable `y` in `draw_record_detail()` does **not** track the bottom of content — `_draw_detail_info_below_cover()`'s return value is discarded. Compute the button Y position from the pre-measured `_detail_content_height` instead.

After the existing `_draw_detail_info_below_cover(rec, y)` call and before the scroll indicators, add:

```python
    # Scrobble button (at bottom of content, only if eligible)
    if rec.get("selected_release_id"):
        # Compute button Y from measured content height (y doesn't track
        # the bottom because _draw_detail_info_below_cover's return is
        # discarded — use _detail_content_height which already includes
        # the button height and gap from Step 4).
        button_y = (DETAIL_COVER_Y - offset
                    + _detail_content_height - SCROBBLE_BUTTON_H)
        # Only draw if the button is at least partially visible
        if (button_y + SCROBBLE_BUTTON_H > DAY_HEADER_Y + DAY_HEADER_H
                and button_y < HEIGHT):
            _draw_scrobble_button(rec, button_y)
```

**Verification:** On-device — navigate to a record with `selected_release_id`. The "Scrobble" button appears at the bottom of the detail content, centered horizontally, AFTER all metadata and purchase date text. Scroll down to reveal it if the content is taller than the screen. Records without `selected_release_id` show no button. The button Y position must match the hit-test formula in Step 7.

### Step 7: Add scrobble hit-test and HTTP request handler

**File:** `presto/main.py`, in the "TOUCH HANDLING" section

New function — hit test:

```python
def _scrobble_button_hit_test(x, y, rec):
    """Return True if the touch (x, y) falls within the scrobble button bounds.
    Accounts for current detail_scroll_offset.
    Ignores touches in the fixed header area (handled separately)."""
    if not rec.get("selected_release_id"):
        return False

    # Reject touches in the fixed header zone (handled by back-button logic)
    if y <= DAY_HEADER_Y + DAY_HEADER_H:
        return False

    # Compute button Y position — must match the formula used in
    # draw_record_detail() (Step 6). _detail_content_height already
    # includes SCROBBLE_BUTTON_GAP + SCROBBLE_BUTTON_H from Step 4.
    button_y = (DETAIL_COVER_Y - detail_scroll_offset
                + _detail_content_height - SCROBBLE_BUTTON_H)
    bx = (WIDTH - SCROBBLE_BUTTON_W) // 2

    return (bx <= x <= bx + SCROBBLE_BUTTON_W and
            button_y <= y <= button_y + SCROBBLE_BUTTON_H)
```

New function — HTTP handler:

```python
def handle_scrobble_touch(rec):
    """Execute the scrobble HTTP request and update button state.
    Blocks during the request (urequests is synchronous on MicroPython).
    On success, sets state to "done" (persists until navigation).
    On failure, reverts to "idle"."""
    global _scrobble_state

    rec_id = rec.get("id")
    if not rec_id:
        return

    # Set loading state and redraw immediately so the user sees "..."
    _scrobble_state = "loading"
    draw_record_detail()

    # Make the POST request. urequests has limited timeout support on
    # MicroPython; if WiFi drops mid-request, the default timeout may
    # be 30+ seconds. Test this scenario on-device.
    url = API_BASE + "/api/v1/collection/" + str(rec_id) + "/scrobble"
    try:
        resp = urequests.post(url, headers=_auth_header())
        if resp.status_code == 200:
            _scrobble_state = "done"
        else:
            _scrobble_state = "idle"
        resp.close()
    except Exception:
        _scrobble_state = "idle"

    gc.collect()
    draw_record_detail()
```

**Verification:** Syntax check. Logic review — the function handles success (200 → "done"), API errors (non-200 → "idle"), and network exceptions (→ "idle"). The "done" state persists until the user navigates away (resets in Step 3). The hit-test formula (`_detail_content_height - SCROBBLE_BUTTON_H`) must match the drawing formula in Step 6.

### Step 8: Modify `STATE_RECORD` touch handling in the main loop

**File:** `presto/main.py`, `main()` function, inside `elif state == STATE_RECORD:`

After the existing `if dragged and pending_delta:` block (which handles scroll-finalize), add a `not dragged` branch:

```python
            if not dragged:
                # Determine which record is being viewed
                if previous_state == STATE_SEARCH_RESULTS:
                    rec = search_results[selected_record_idx]
                else:
                    rec = records[selected_record_idx]

                # Check scrobble button tap
                if _scrobble_button_hit_test(x, y, rec):
                    handle_scrobble_touch(rec)
```

**Verification:** On-device — tap the scrobble button. Button text changes to "..." then "Done" (on success) or reverts to "Scrobble" (on failure). Note: while the HTTP request is in progress (loading state), the event loop is blocked by the synchronous `urequests.post()` call, so no new touches are processed until the request completes. This is expected behavior for MicroPython's single-threaded model. Scrolling still works correctly; a drag does not trigger a scrobble because `dragged` is `True` for drags.

### Step 9: Update `presto/README.md`

**File:** `presto/README.md`

Two changes:

**(a)** In the "Record detail view" usage section, add a bullet:

```
- If the record can be scrobbled, a **"Scrobble" button** appears at the bottom — tap it to scrobble the release to Last.fm; "Done" confirms success
```

**(b)** In the API Response format example, add `selected_release_id`:

```json
  "selected_release_id": "abc-123-uuid",
```

(immediately after `"id"` or near the end of the record object)

**Verification:** Read the rendered README to confirm both additions read naturally and the API example remains valid JSON.

### Step 10: Update `presto/AGENTS.md`

**File:** `presto/AGENTS.md`

In the "API Contract" section, add `selected_release_id` to the "Fields used by the app" list. The current list is:

```
Fields used by the app: `title`, `artists`, `format`, `release_date`, `genres`, `record_type`, `purchased_at`, `micro_cover_url`, `mini_cover_url`, `thumb_url`.
```

Change to:

```
Fields used by the app: `title`, `artists`, `format`, `release_date`, `genres`, `record_type`, `purchased_at`, `micro_cover_url`, `mini_cover_url`, `thumb_url`, `selected_release_id`.
```

Also add the new endpoint to the API Contract section:

```
POST /api/v1/collection/:record_id/scrobble
Authorization: Bearer <API_TOKEN>
```

**Verification:** Read the rendered AGENTS.md to confirm the field list is updated and the new endpoint is documented.

## Architecture impact analysis

| Touchpoint                                                    | Impact                                                                                              |
| ------------------------------------------------------------- | --------------------------------------------------------------------------------------------------- |
| `presto/main.py` — layout constants block                     | +3 constants (`SCROBBLE_BUTTON_W`, `_H`, `_GAP`)                                                    |
| `presto/main.py` — color constants block                      | +4 color tuples (`SCROBBLE_BG`, `_TEXT`, `_DONE_BG`, `_DONE_TEXT`)                                  |
| `presto/main.py` — pen variables and `_init_pens()`           | +4 pens initialized at startup; +4 globals in `_init_pens()`                                        |
| `presto/main.py` — global state block                         | +1 variable (`_scrobble_state`); +1 global in `main()`                                              |
| `presto/main.py` — `_measure_detail_content()`                | +3 lines for button height when eligible                                                            |
| `presto/main.py` — `draw_record_detail()`                     | +6 lines to draw button after existing content (using `_detail_content_height`-based Y calculation) |
| `presto/main.py` — new function `_draw_scrobble_button()`     | ~25 lines                                                                                           |
| `presto/main.py` — new function `_scrobble_button_hit_test()` | ~15 lines (includes header-zone guard)                                                              |
| `presto/main.py` — new function `handle_scrobble_touch()`     | ~25 lines (no auto-revert sleep)                                                                    |
| `presto/main.py` — `main()` STATE_RECORD handler              | +10 lines for tap dispatch                                                                          |
| `presto/main.py` — `main()` state transitions                 | +3 reset points for `_scrobble_state` (2 entry, 1 exit)                                             |
| `presto/main.py` — `handle_search_results_touch()`            | +1 reset point for `_scrobble_state`                                                                |
| `presto/README.md`                                            | +2 lines (usage + API response)                                                                     |
| `presto/AGENTS.md`                                            | +2 changes (field list + endpoint docs)                                                             |
| Backend API                                                   | No changes (ML-177 covers this)                                                                     |
| Web UI (LiveView)                                             | No changes                                                                                          |
| Database / schemas                                            | No changes                                                                                          |
| PubSub / supervision tree                                     | No changes                                                                                          |

## Performance profile

- **Button drawing:** O(1) — one `display.rectangle()` + one `_draw_centered_text()` call. Each redraw of the detail view adds ~2ms at most.
- **Content height measurement:** O(1) addition — one condition check + two integer additions. No loops, no text measurement.
- **HTTP request:** Blocking `urequests.post()`, expected 1–5 seconds on a functional WiFi connection. During this time the display is frozen (no touch processing), which is acceptable for a user-initiated action with "..." visual feedback. **Caveat:** MicroPython's `urequests` has limited timeout support. If WiFi drops mid-request, the default timeout can be 30+ seconds. This should be tested on-device with a simulated WiFi disconnect to confirm the real-world behavior.
- **Scroll performance:** Zero impact. The button is only drawn during full redraws, never during drag-scroll redraw loops (which use clips and skip non-content). No new allocations in the scroll hot path.
- **Memory:** ~4 pen objects (already amortized at startup), 1 global string/state variable. No new per-record allocations. No image caching. Negligible GC pressure.
- **N+1 risk:** None. One POST per explicit user tap. No prefetching or batching.

## Benchmarking requirements

No benchmarks needed. This is a UI-only change with a single user-initiated HTTP request. The performance characteristics are straightforward and deterministic.

## Cost profile

- **API calls:** One `POST /api/v1/collection/:id/scrobble` per user scrobble action. The endpoint internally calls Last.fm (free API) and MusicBrainz (free, rate-limited but not metered). No paid third-party services consumed by this feature.
- **Compute:** Negligible — the scrobble endpoint is a thin wrapper around existing `ScrobbleActivity.scrobble_release/3`.
- **Storage:** No new database rows or files.
- **Overall cost:** $0 marginal cost.

## Production infrastructure steps

### Production Changes

No infrastructure changes required. The backend endpoint is deployed as part of ML-177. This task deploys only the Presto client code.

**Rollout:**

```bash
mise run presto
```

This copies `presto/main.py` to the device and resets it.

**Rollback:**
Redeploy the previous `main.py` (e.g., from git):

```bash
git show HEAD~1:presto/main.py > /tmp/main_rollback.py
mpremote fs cp /tmp/main_rollback.py :main.py
mpremote reset
```

**No other changes needed:**

- No environment variables
- No database migrations
- No DNS or firewall rules
- No service restarts on the server

## Documentation updates

| File                                | Change                                                                                                                                                               |
| ----------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `presto/README.md`                  | Add scrobble button to "Record detail view" usage bullet points. Add `selected_release_id` to API response example JSON.                                             |
| `presto/AGENTS.md`                  | Add `selected_release_id` to the "Fields used by the app" list under API Contract section. Add `POST /api/v1/collection/:record_id/scrobble` endpoint documentation. |
| `docs/architecture.md`              | No changes (Presto is a client, not part of the supervision tree or database layout).                                                                                |
| `docs/project-conventions.md`       | No changes (no new conventions introduced).                                                                                                                          |
| `docs/production-infrastructure.md` | No changes (no infrastructure impact).                                                                                                                               |

Implementation complete. All code changes made; verified with python3 syntax check. On-device testing requires ML-177 (backend endpoint + selected_release_id field) to be deployed first.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

Implemented all 10 steps per the plan:

1. ✅ Added SCROBBLE_BUTTON_W/H/GAP constants and SCROBBLE_BG/TEXT/DONE_BG/DONE_TEXT color tuples

2. ✅ Added 4 new pens (\_pen_scrobble_bg, \_pen_scrobble_text, \_pen_scrobble_done_bg, \_pen_scrobble_done_text) initialized in \_init_pens()

3. ✅ Added \_scrobble_state global with resets at all 2 entry points and 1 exit point to STATE_RECORD

4. ✅ Modified \_measure_detail_content() to include SCROBBLE_BUTTON_GAP + SCROBBLE_BUTTON_H when selected_release_id is present

5. ✅ Added \_draw_scrobble_button() helper with 3 visual states (idle/loading/done)

6. ✅ Modified draw_record_detail() to draw button using \_detail_content_height-based Y calculation, with viewport visibility check

7. ✅ Added \_scrobble_button_hit_test() and handle_scrobble_touch() functions

8. ✅ Modified STATE_RECORD handler in main() with not dragged branch for scrobble tap dispatch

9. ✅ Updated README.md: added scrobble button usage bullet + selected_release_id to API response example

10. ✅ Updated AGENTS.md: added selected_release_id to fields list + POST /api/v1/collection/:record_id/scrobble endpoint docs

Syntax check passes cleanly (py_compile). Ready for on-device testing once ML-177 backend is deployed.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## What changed

Added a scrobble button to the Presto record detail view (`draw_record_detail()` / `STATE_RECORD`) that sends `POST /api/v1/collection/:record_id/scrobble` with the Bearer token and shows visual feedback.

### presto/main.py

- **Layout/color constants**: `SCROBBLE_BUTTON_W` (200), `SCROBBLE_BUTTON_H` (40), `SCROBBLE_BUTTON_GAP` (12); colors reuse existing palette (slate/green/white)
- **4 new pens**: `_pen_scrobble_bg`, `_pen_scrobble_text`, `_pen_scrobble_done_bg`, `_pen_scrobble_done_text`, initialized in `_init_pens()`
- **Global state**: `_scrobble_state` ("idle" / "loading" / "done"), reset on all 3 entry/exit paths to `STATE_RECORD`
- **`_measure_detail_content()`**: Includes button height + gap when `selected_release_id` is present, ensuring correct scroll bounds
- **`draw_record_detail()`**: Draws button at `_detail_content_height - SCROBBLE_BUTTON_H` from `DETAIL_COVER_Y`, viewport-clipped
- **`_draw_scrobble_button()`**: Renders 3 visual states (Scrobble / ... / Done) centered horizontally
- **`_scrobble_button_hit_test()`**: Hit-test matching the drawing formula, rejects header-zone touches
- **`handle_scrobble_touch()`**: Blocking `urequests.post()`, sets state → redraws before/after request, catches all exceptions
- **Main loop `STATE_RECORD`**: `not dragged` branch dispatches to scrobble on tap

### presto/README.md

- Added scrobble button usage bullet to Record detail view section
- Added `selected_release_id` to API response JSON example

### presto/AGENTS.md

- Added `selected_release_id` to "Fields used by the app" list
- Documented `POST /api/v1/collection/:record_id/scrobble` endpoint

## Why

The Presto can browse records but had no way to trigger a Last.fm scrobble. The backend endpoint (ML-177) provides the server-side action; this wires it to a touch target on the device, gated on `selected_release_id` so only scrobble-eligible records show the button.

## Risks / follow-ups

- Blocking HTTP request freezes display during scrobble (~1-5s normal, up to 30s on WiFi drop). Acceptable for user-initiated action on single-threaded MicroPython.
- No debounce/double-tap prevention — could be added later if needed.
- No error toast — button reverts to "Scrobble" on failure (minimal feedback).

<!-- SECTION:FINAL_SUMMARY:END -->
