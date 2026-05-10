---
id: doc-17
title: >-
  Implementation Plan: ML-176.2 — Presto splash screen, search views, and
  on-screen keyboard
type: specification
created_date: "2026-05-10 13:48"
updated_date: "2026-05-10 13:56"
tags:
  - presto
  - search
  - micropython
  - implementation-plan
---

# Implementation Plan — ML-176.2: Presto splash screen, search views, and on-screen keyboard

## 0. Dependencies

- **ML-176.1** (In Progress): API accepts `q` parameter on `GET /api/v1/collection`. Must be completed before `fetch_search_results()` works end-to-end, but Presto-side implementation can proceed in parallel — the `q` parameter is additive (absent → same as current behavior). Presto code can be written and syntax-checked independently.

## 1. Objective Alignment

The current `records_on_the_day.py` is a single-purpose calendar app that boots directly into today's records. The objective is to refactor it into a multi-screen app: a **splash screen** (home) with two entry points ("Search Collection" and "Today's Records"), a **search input view** with a custom on-screen QWERTY/numbers keyboard, and a **search results view** that reuses the existing record-list rendering infrastructure. The app must also navigate correctly (back from detail returns to the origin screen) and always return to the splash screen on display wake.

Each section below maps a concrete implementation step to a verifiable outcome.

## 2. Simplicity and Alternatives Considered

**Chosen approach:** Everything stays in the single `records_on_the_day.py` file. No new modules, no class refactor. Use flat state constants and new drawing/touch-handler functions. Reuse existing `_draw_record_list()`, `_draw_record_row()`, `prepare_records_for_display()`, `draw_record_detail()`, and scroll infrastructure verbatim — search results is just `STATE_DAY` with a different header and data source.

**Alternatives evaluated and rejected:**

- _Separate files per screen_ — adds import complexity on MicroPython, increases flash fragmentation risk. Rejected.
- _Class-based screen hierarchy_ — class allocation and method dispatch add memory overhead. Flat function dispatch keeps GC pressure low and is consistent with existing code. Rejected.
- _Virtual keyboard as a component module_ — same fragmentation argument. Inline in the main file keeps everything in one compilation unit. Rejected.
- _Shift/caps support on keyboard_ — task explicitly says lowercase only. Deferred.
- _Infinite scroll for search results_ — task explicitly says 20 per page, no infinite scroll. Rejected.

## 3. Completeness and Sequencing

### Step 1: Add new state constants and global variables

Add at the top of the state globals section (after `STATE_RECORD = 3`):

```python
STATE_HOME = 4
STATE_SEARCH_INPUT = 5
STATE_SEARCH_RESULTS = 6
```

Change default `state = STATE_HOME` (was `STATE_STARTUP`).

Add new globals:

```python
search_query = ""           # Current search buffer (max ~50 chars)
search_results = []         # Records from search API
search_results_error = False
search_scroll_offset = 0    # Separate scroll offset for search results
_search_content_height = 0  # Separate content height cache for search results
keyboard_mode = "alpha"     # "alpha" or "numbers"
previous_state = None       # Track where we came from for detail view back
```

Remove `STATE_STARTUP = 0`. Replace all references to `STATE_STARTUP` with `STATE_HOME`.

**Verification:** `python3 -c "import py_compile; py_compile.compile('records_on_the_day.py', cfile='/tmp/records_on_the_day.pyc', doraise=True)"` passes.

### Step 2: Add `fetch_search_results()` API client function

**Depends on: ML-176.1** (backend `q` parameter support).

Add after `fetch_records()` in the API section:

```python
def fetch_search_results(query):
    """Fetch search results from the API.
    Returns (records_list, error_flag). Same shape as fetch_records().
    """
    # urequests doesn't have url-encode built-in; hand-encode common chars
    encoded = query.replace(" ", "+")
    url = API_BASE + "/api/v1/collection?q=" + encoded + "&limit=20"

    try:
        resp = urequests.get(url, headers=_auth_header())
        if resp.status_code == 200:
            data = resp.json()
            recs = data.get("records", [])
            resp.close()
            gc.collect()
            return recs, False
        else:
            resp.close()
            gc.collect()
            return [], True
    except Exception:
        gc.collect()
        return [], True
```

**Verification:** After ML-176.1 is deployed, tapping OK on keyboard with a valid query shows results. Tapping OK with no network shows "Could not reach server".

### Step 3: Implement STATE_HOME (splash screen)

#### 3a. Layout constants

```python
HOME_BUTTON_W = WIDTH - 80
HOME_BUTTON_H = 90
HOME_BUTTON_X = 40
HOME_BUTTON1_Y = 220
HOME_BUTTON2_Y = HOME_BUTTON1_Y + HOME_BUTTON_H + 30
HOME_TITLE_Y = 100
HOME_TITLE = "Music Library"
```

#### 3b. Drawing function `draw_home_screen()`

```python
def draw_home_screen():
    display.set_pen(_pen_bg)
    display.clear()

    display.set_pen(_pen_title)
    display.set_font("bitmap14_outline")
    tw = display.measure_text(HOME_TITLE, scale=1)
    display.text(HOME_TITLE, (WIDTH - tw) // 2, HOME_TITLE_Y, scale=1)

    _draw_home_button(HOME_BUTTON1_Y, "Search Collection")
    _draw_home_button(HOME_BUTTON2_Y, "Today's Records")

    presto.update()

def _draw_home_button(y, label):
    display.set_pen(_pen_cell_bg)
    display.rectangle(HOME_BUTTON_X, y, HOME_BUTTON_W, HOME_BUTTON_H)
    display.set_pen(_pen_header_text)
    display.set_font("bitmap8")
    tw = display.measure_text(label, scale=1)
    tx = HOME_BUTTON_X + (HOME_BUTTON_W - tw) // 2
    ty = y + (HOME_BUTTON_H - 8) // 2
    display.text(label, tx, ty, scale=1)
```

**Verification:** On boot, splash screen renders with two buttons. Tapping "Today's Records" transitions to STATE_MONTH. Tapping "Search Collection" transitions to STATE_SEARCH_INPUT.

### Step 4: Implement on-screen keyboard (STATE_SEARCH_INPUT)

#### 4a. Keyboard layout constants

```python
KB_MARGIN = 20
KB_KEY_GAP = 4
KB_KEY_H = 48
KB_KEY_W = (WIDTH - 2 * KB_MARGIN - 9 * KB_KEY_GAP) // 10  # computed from 10-key alpha row

KB_INPUT_Y = 30
KB_INPUT_H = 40
KB_INPUT_MARGIN = 40
KB_ROWS_START_Y = KB_INPUT_Y + KB_INPUT_H + 16

ALPHA_KEYS = [
    list("qwertyuiop"),
    list("asdfghjkl"),
    list("zxcvbnm"),
]

NUM_KEYS = [
    list("1234567890"),
    list("!@#$%^&*()_"),
]
```

#### 4b. Drawing function `draw_search_input()`

```python
def draw_search_input():
    display.set_pen(_pen_bg)
    display.clear()

    # Header with "Search Collection" title and Back (→ Home) button
    _draw_search_input_header()

    # Query text field
    display.set_pen(_pen_cell_bg)
    display.rectangle(KB_INPUT_MARGIN, KB_INPUT_Y, WIDTH - 2 * KB_INPUT_MARGIN, KB_INPUT_H)
    display.set_pen(_pen_header_text)
    display.set_font("bitmap8")
    display.text(search_query, KB_INPUT_MARGIN + 8, KB_INPUT_Y + 12, scale=1)

    display.set_font("bitmap8")
    keys_matrix = ALPHA_KEYS if keyboard_mode == "alpha" else NUM_KEYS
    toggle_label = "123" if keyboard_mode == "alpha" else "ABC"

    cy = KB_ROWS_START_Y
    for row_keys in keys_matrix:
        num_keys = len(row_keys)
        total_gap = (num_keys - 1) * KB_KEY_GAP
        total_key_w = num_keys * KB_KEY_W
        row_start_x = (WIDTH - total_key_w - total_gap) // 2
        for i, char in enumerate(row_keys):
            kx = row_start_x + i * (KB_KEY_W + KB_KEY_GAP)
            _draw_key(kx, cy, char, KB_KEY_W, KB_KEY_H)
        cy += KB_KEY_H + KB_KEY_GAP

    # Bottom row: toggle | space | backspace | OK
    bottom_w = (WIDTH - 2 * KB_MARGIN - 3 * KB_KEY_GAP) // 4
    bx = KB_MARGIN
    _draw_key(bx, cy, toggle_label, bottom_w, KB_KEY_H)
    bx += bottom_w + KB_KEY_GAP
    _draw_key(bx, cy, "Space", bottom_w, KB_KEY_H)
    bx += bottom_w + KB_KEY_GAP
    _draw_key(bx, cy, "<-", bottom_w, KB_KEY_H)
    bx += bottom_w + KB_KEY_GAP
    ok_pen = _pen_dim_text if search_query == "" else _pen_header_text
    _draw_key(bx, cy, "OK", bottom_w, KB_KEY_H, text_pen=ok_pen)

    presto.update()

def _draw_key(x, y, label, w, h, text_pen=None):
    display.set_pen(_pen_cell_bg)
    display.rectangle(x, y, w, h)
    pen = text_pen if text_pen is not None else _pen_normal_text
    display.set_pen(pen)
    tw = display.measure_text(label, scale=1)
    tx = x + (w - tw) // 2
    ty = y + (h - 8) // 2
    display.text(label, tx, ty, scale=1)
```

#### 4c. Keyboard touch handler `handle_search_input_touch(x, y)`

```python
def handle_search_input_touch(x, y):
    global search_query, keyboard_mode, state, search_results, search_results_error
    global search_scroll_offset, _search_content_height, previous_state

    # Header Back button → Home
    if BACK_X <= x <= BACK_X + BACK_W and BACK_Y <= y <= BACK_Y + BACK_H:
        state = STATE_HOME
        draw_home_screen()
        return

    action = _keyboard_hit_test(x, y)
    if action is None:
        return

    if action == "toggle":
        keyboard_mode = "numbers" if keyboard_mode == "alpha" else "alpha"
        draw_search_input()
        return

    if action == "space":
        if len(search_query) < 50:
            search_query += " "
        draw_search_input()
        return

    if action == "backspace":
        search_query = search_query[:-1]
        draw_search_input()
        return

    if action == "ok":
        if not search_query.strip():
            return
        draw_status("Searching for:\n" + search_query)
        if not ensure_wifi_connected():
            search_results_error = True
            search_results = []
            state = STATE_SEARCH_RESULTS
            draw_search_results()
            return
        recs, had_error = fetch_search_results(search_query)
        search_results = recs
        search_results_error = had_error
        search_scroll_offset = 0
        if not had_error and recs:
            prepare_records_for_display(recs)
        previous_state = STATE_SEARCH_INPUT
        state = STATE_SEARCH_RESULTS
        draw_search_results()
        return

    # Character key
    if len(search_query) < 50 and len(action) == 1:
        search_query += action
        draw_search_input()
```

#### 4d. Hit-testing function `_keyboard_hit_test(x, y)`

```python
def _keyboard_hit_test(x, y):
    if y < KB_ROWS_START_Y:
        return None

    keys_matrix = ALPHA_KEYS if keyboard_mode == "alpha" else NUM_KEYS

    cy = KB_ROWS_START_Y
    for row_keys in keys_matrix:
        num_keys = len(row_keys)
        total_gap = (num_keys - 1) * KB_KEY_GAP
        total_key_w = num_keys * KB_KEY_W
        row_start_x = (WIDTH - total_key_w - total_gap) // 2
        for i, char in enumerate(row_keys):
            kx = row_start_x + i * (KB_KEY_W + KB_KEY_GAP)
            if kx <= x < kx + KB_KEY_W and cy <= y < cy + KB_KEY_H:
                return char
        cy += KB_KEY_H + KB_KEY_GAP

    # Bottom row
    bottom_w = (WIDTH - 2 * KB_MARGIN - 3 * KB_KEY_GAP) // 4
    bx = KB_MARGIN
    if bx <= x < bx + bottom_w and cy <= y < cy + KB_KEY_H:
        return "toggle"
    bx += bottom_w + KB_KEY_GAP
    if bx <= x < bx + bottom_w and cy <= y < cy + KB_KEY_H:
        return "space"
    bx += bottom_w + KB_KEY_GAP
    if bx <= x < bx + bottom_w and cy <= y < cy + KB_KEY_H:
        return "backspace"
    bx += bottom_w + KB_KEY_GAP
    if bx <= x < bx + bottom_w and cy <= y < cy + KB_KEY_H:
        return "ok"

    return None
```

#### 4e. Key press visual feedback

Brief highlight flash on key press. Call `_flash_key()` before the action is applied; the subsequent `draw_search_input()` overwrites it:

```python
def _flash_key(kx, ky, kw, kh, label):
    _draw_key(kx, ky, label, kw, kh, text_pen=_pen_today_text)
    display.set_pen(_pen_arrow)
    display.rectangle(kx, ky, kw, kh)
    presto.update()
    time.sleep(0.05)
```

**Verification:** All keys appear on a 720×720 display. Tapping letter keys appends to the query field. Backspace removes last char. 123/ABC toggles layouts. OK dim when empty and no-ops. OK with text triggers API call.

### Step 5: Implement STATE_SEARCH_RESULTS

#### 5a. Drawing function `draw_search_results()`

Reuses `_draw_record_row()` from the day view. Unique elements: search-specific header, own scroll state, empty/error states.

```python
def draw_search_results():
    global search_scroll_offset
    display.set_pen(_pen_bg)
    display.clear()

    _draw_search_results_header()

    if search_results_error:
        _draw_search_error()
        presto.update()
        return

    if not search_results:
        _draw_search_empty()
        presto.update()
        return

    _draw_search_record_list()
    presto.update()

def _draw_search_results_header():
    display.set_pen(_pen_cell_bg)
    display.rectangle(0, DAY_HEADER_Y, WIDTH, DAY_HEADER_H)

    # Back button
    bx, by = BACK_X, BACK_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(bx, by, BACK_W, BACK_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text("<", bx, by, BACK_W, BACK_H, DAY_COUNT_TEXT_H)

    # Title "Search: <query>" — truncate if needed
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    label = "Search: " + search_query
    max_w = WIDTH - (BACK_X + BACK_W + 8) - 8
    if display.measure_text(label, scale=1) > max_w:
        display_ellipsis = "..."
        while (display.measure_text("Search: " + search_query + display_ellipsis, scale=1) > max_w
               and len(search_query) > 0):
            search_query = search_query[:-1]
        label = "Search: " + search_query + display_ellipsis if search_query else "Search: ..."
    tw = display.measure_text(label, scale=1)
    display.text(label, (WIDTH - tw)//2,
                 DAY_HEADER_Y + (DAY_HEADER_H - DAY_HEADER_TEXT_H)//2, scale=1)
```

#### 5b. Search record list scroll (own state)

```python
def _draw_search_record_list():
    global search_scroll_offset
    max_offset = _search_max_scroll_offset()
    search_scroll_offset = min(max(0, search_scroll_offset), max_offset)

    if search_scroll_offset > 0:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        display.text("^", WIDTH // 2 - 8, RECORD_START_Y - 28, scale=1)

    cy = RECORD_START_Y - search_scroll_offset
    for rec in search_results:
        row_h = rec.get("_row_height", THUMB_SIZE + 8)
        row_bottom = cy + row_h
        if row_bottom <= RECORD_START_Y:
            cy = row_bottom
            continue
        if cy >= HEIGHT - 28:
            break
        _draw_record_row(rec, cy)
        cy = row_bottom

    if search_scroll_offset < max_offset:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        display.text("v", WIDTH // 2 - 8, HEIGHT - 24, scale=1)

def _search_max_scroll_offset():
    viewport_h = HEIGHT - RECORD_START_Y - 28
    return max(0, _search_content_height - viewport_h)
```

#### 5c. Generic `prepare_records_for_display(recs=None)`

Make the existing preparation pipeline accept an optional list so both `records` and `search_results` can use it:

```python
def prepare_records_for_display(recs=None):
    global _content_height, _search_content_height, records, search_results
    if recs is None:
        recs = records
    display.set_font("bitmap8")
    if recs is search_results:
        _search_content_height = 0
    else:
        _content_height = 0
    for rec in recs:
        _prepare_record_for_display(rec)
        if recs is search_results:
            _search_content_height += rec.get("_row_height", THUMB_SIZE + 8)
        else:
            _content_height += rec.get("_row_height", THUMB_SIZE + 8)
    preload_record_thumbnails(recs)
    gc.collect()
```

Similarly parameterize `preload_record_thumbnails(recs=None)`.

#### 5d. Empty and error states

```python
def _draw_search_empty():
    display.set_pen(_pen_dim_text)
    display.set_font("bitmap8")
    msg = "No records found"
    mw = display.measure_text(msg, scale=1)
    display.text(msg, (WIDTH - mw) // 2, HEIGHT // 2 - 10, scale=1)

def _draw_search_error():
    display.set_pen(_pen_error)
    display.set_font("bitmap8")
    msg = "Could not reach server"
    mw = display.measure_text(msg, scale=1)
    display.text(msg, (WIDTH - mw) // 2, HEIGHT // 2 - 20, scale=1)
    display.set_pen(_pen_dim_text)
    hint = "Tap to retry"
    hw = display.measure_text(hint, scale=1)
    display.text(hint, (WIDTH - hw) // 2, HEIGHT // 2 + 10, scale=1)
```

**Verification:** Search results display with cover art, titles, artists, format, year — identical layout to day view. Back returns to STATE_SEARCH_INPUT with query preserved. Tapping a record opens detail. Empty/error states work. Scroll works identically to day view.

### Step 6: Navigation state tracking for Back from detail

Track `previous_state` on transitions to `STATE_RECORD`:

- From `STATE_DAY` → `previous_state = STATE_DAY`
- From `STATE_SEARCH_RESULTS` → `previous_state = STATE_SEARCH_RESULTS`

On Back in `STATE_RECORD`, navigate to `previous_state` instead of always `STATE_DAY`.

**Verification:** Detail view Back → search results when entered from search. Back → day when entered from day.

### Step 7: Update existing views for Back-to-Home

#### 7a. Month view Home button

Add a "Home" button in the month header, leftmost position. Month header layout becomes: `[Home] [<] [Month Year] [>]`.

Update `_draw_month_header()` to draw the home button and shift the left arrow right. Update `handle_month_touch()` to check the home button first.

#### 7b. Display wake returns to home

In `wake_display()`, set `state = STATE_HOME` before calling `redraw_current_view()`.

#### 7c. `redraw_current_view()` updated

Add cases for `STATE_HOME`, `STATE_SEARCH_INPUT`, `STATE_SEARCH_RESULTS`.

**Verification:** From any view, after display sleep + wake, splash screen appears. Month view has Home button. Search input Back → Home.

### Step 8: Update `main()` globals and boot flow

Change boot flow:

1. `state = STATE_HOME`
2. After WiFi + NTP sync + `set_today()`, call `draw_home_screen()` — no auto-fetch of today's records
3. User must tap "Today's Records" to trigger the calendar flow

**Verification:** On cold boot, splash screen is the first thing shown. No API call until user taps a button.

### Step 9: Update main loop dispatch

Add handlers for `STATE_HOME`, `STATE_SEARCH_INPUT`, `STATE_SEARCH_RESULTS` in the main loop. Implement `handle_home_touch(x, y)` for "Search Collection" and "Today's Records" buttons. Implement drag-scroll for `STATE_SEARCH_RESULTS` mirroring day-view scroll. Wire `previous_state` tracking for detail navigation.

```python
def handle_home_touch(x, y):
    global state

    # "Search Collection"
    if (HOME_BUTTON_X <= x <= HOME_BUTTON_X + HOME_BUTTON_W and
        HOME_BUTTON1_Y <= y <= HOME_BUTTON1_Y + HOME_BUTTON_H):
        state = STATE_SEARCH_INPUT
        search_query = ""
        keyboard_mode = "alpha"
        draw_search_input()
        return

    # "Today's Records" → month view with today highlighted
    if (HOME_BUTTON_X <= x <= HOME_BUTTON_X + HOME_BUTTON_W and
        HOME_BUTTON2_Y <= y <= HOME_BUTTON2_Y + HOME_BUTTON_H):
        view_year = today_year
        view_month = today_month
        selected_day = today_day
        state = STATE_MONTH
        draw_month_view()
        return
```

**Design decision:** "Today's Records" goes to month view (with today highlighted) rather than directly to day view. This gives the user full calendar context — they can tap today or any other day. Consistent with the existing month-first navigation pattern.

**Verification:** All touch handlers dispatch correctly. No crashes on state transitions. Scroll works in search results. Record taps in search results open detail.

### Step 10: Delete unused `STATE_STARTUP` references

Remove `STATE_STARTUP = 0`. Replace remaining references with `STATE_HOME`.

**Verification:** `grep -n "STATE_STARTUP" records_on_the_day.py` returns nothing.

### Step 11: Test and deploy

1. Syntax check: `python3 -c "import py_compile; py_compile.compile('records_on_the_day.py', cfile='/tmp/records_on_the_day.pyc', doraise=True)"`
2. Verify ML-176.1 is deployed to production
3. Deploy to Presto: `mise run presto`
4. Manual verification on device for all 19 acceptance criteria

## 4. Verifiability

| Step | Verification                                                                             |
| ---- | ---------------------------------------------------------------------------------------- |
| 1    | Syntax check passes                                                                      |
| 2    | Functional after ML-176.1 deployed; OK triggers API call, network error handled          |
| 3    | Presto boots to splash screen; two buttons visible and tappable                          |
| 4    | All keys visible; typing works; backspace works; 123/ABC toggles; OK dim when empty      |
| 5    | Search results render with cover art; scroll works; empty/error states display correctly |
| 6    | Back from detail → correct origin (search results or day view)                           |
| 7    | Home button on month view works; wake always returns to home                             |
| 8    | On cold boot, splash screen shows first                                                  |
| 9    | All touch handlers dispatch correctly; no crashes                                        |
| 10   | No STATE_STARTUP references remain                                                       |
| 11   | All 19 ACs pass on physical device                                                       |

## 5. Architecture Impact Analysis

| Touchpoint                    | Impact                                                                                                                                                                                                                 |
| ----------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `records_on_the_day.py`       | Primary change. ~250–350 new lines for keyboard, splash, search views. Existing drawing functions reused. `prepare_records_for_display()` and `preload_record_thumbnails()` made generic (accept optional list param). |
| `collection_controller.ex`    | **No change** — handled by ML-176.1                                                                                                                                                                                    |
| `collection_json.ex`          | **No change** — `index/1` already returns correct shape                                                                                                                                                                |
| `Collection.search_records/2` | **No change** — already accepts query string                                                                                                                                                                           |
| Routes                        | **No change** — existing `GET /api/v1/collection` reused                                                                                                                                                               |
| PubSub                        | No impact                                                                                                                                                                                                              |
| Supervision tree              | No impact                                                                                                                                                                                                              |
| External APIs                 | Search API call added to Presto. Same auth header, same error handling pattern as `fetch_records()`                                                                                                                    |
| Month view UI                 | Header gains Home button; left/right arrow positions shift right                                                                                                                                                       |

## 6. Performance Profile

- **Keyboard drawing:** O(1) — fixed ~34 keys drawn per keystroke. Each key is a rectangle + text call. No network calls during typing. Estimated <5ms per redraw on RP2350B at 150 MHz.
- **Search results rendering:** O(n) where n ≤ 20 records per page. Same scroll performance rules as day view: layout/text pre-computed in `prepare_records_for_display()`, drag scroll uses placeholders for thumbnails. No measurable difference from day view.
- **Memory:** Search query capped at 50 chars. Keyboard layout arrays ~200 bytes total (module-level constants). Search results reuse `search_results` list (same structure as `records`). GC pressure identical to current app.
- **Network:** One additional API call per search (same `urequests` pattern). No network calls during scroll or typing.
- **N+1 risks:** None. Both API endpoints return full record data in a single response. Thumbnails preloaded in batch.
- **Latency:** Same 1–3 second API call latency as day-view fetch. Keyboard is instant (local only).

## 7. Benchmarking Requirements

No formal benchmarks needed. The keyboard is a fixed-size static layout with O(1) redraw. Search results use the same rendering path as day view, already validated on hardware. The only quantitative check:

- **Keyboard tap-to-redraw latency:** Verify that tapping a key and seeing the character appear feels instant (<100ms). If noticeable lag occurs, profile with `time.ticks_ms()` around `draw_search_input()`.

Manual verification on the Presto device is sufficient.

## 8. Cost Profile

No additional paid resources:

- **API calls:** Search uses the same `GET /api/v1/collection` endpoint (ML-176.1). No third-party API calls. Incremental server load is one extra request per search, same magnitude as a day-view request.
- **Storage:** No new storage requirements. Keyboard layouts are constant strings in the MicroPython module.
- **Compute:** No additional server-side processing beyond what `search_records` already handles.

## 9. Production Infrastructure Steps

### Production Changes

**1. Deploy ML-176.1 backend change first**

```bash
git push origin main  # triggers Coolify deploy (includes ML-176.1 commit)
```

Verify: `curl -H "Authorization: Bearer <token>" "https://music-library.claudio-ortolina.org/api/v1/collection?q=test&limit=1"` returns results.

**2. Deploy updated Presto firmware**

```bash
mise run presto
```

Rollback: copy the previous version of `records_on_the_day.py` to the device.

No environment variable changes, no service provisioning, no DNS changes, no firewall rules.

## 10. Documentation Updates

| File                                | Change needed                                                                                                                                                                                                                                                                                                       |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `presto/README.md`                  | Add sections: "Splash Screen", "Search", "On-Screen Keyboard". Update "Features" list. Add API endpoint `GET /api/v1/collection?q=&limit=20` to "API Endpoint" section with response format.                                                                                                                        |
| `presto/AGENTS.md`                  | Update "State Management" section: add `STATE_HOME`, `STATE_SEARCH_INPUT`, `STATE_SEARCH_RESULTS`. Update "API Contract" section with search endpoint. Update "Scroll Performance" to mention per-view offset/cache discipline for search results. Add keyboard constraints: fixed layouts, no shift, max 50 chars. |
| `docs/architecture.md`              | No change needed.                                                                                                                                                                                                                                                                                                   |
| `docs/project-conventions.md`       | No change needed.                                                                                                                                                                                                                                                                                                   |
| `docs/production-infrastructure.md` | No change needed.                                                                                                                                                                                                                                                                                                   |
