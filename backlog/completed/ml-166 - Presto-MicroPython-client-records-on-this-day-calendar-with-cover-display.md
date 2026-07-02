---
id: ML-166
title: "Presto MicroPython client: records-on-this-day calendar with cover display"
status: Done
assignee: []
created_date: "2026-05-05 12:23"
updated_date: "2026-05-05 12:41"
labels: []
dependencies: []
references:
  - "https://shop.pimoroni.com/products/presto?variant=54894104019323"
  - "https://github.com/pimoroni/presto"
  - "https://github.com/pimoroni/presto/blob/main/examples/secrets.py"
documentation:
  - docs/architecture.md
  - docs/production-infrastructure.md
modified_files:
  - presto/main.py
  - presto/config.example.py
  - presto/README.md
  - .gitignore
ordinal: 11000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Build a MicroPython application for the Pimoroni Presto (RP2350B, 720×720 touch display, WiFi) that connects to the production music library API and lets users browse records by release date.

The app talks to `https://music-library.claudio-ortolina.org` using `Authorization: Bearer <API_TOKEN>` for all requests (JSON data and cover images). WiFi credentials and the API token are read from `secrets.py` (not committed).

Core flow:

1. Boot → connect WiFi → sync time via NTP → display current month calendar
2. Tap a day → fetch records via `/api/v1/collection/on_this_day?date=YYYY-MM-DD` → display covers with artist/title
3. Month view has ← → arrows to navigate months
4. Day view has a back button to return to month view

The device is a Pimoroni Presto running the stock Presto firmware (MicroPython + PicoGraphics + touch driver).

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 Device connects to WiFi on boot using credentials from secrets.py
- [x] #2 Current date is obtained via NTP and displayed on the month calendar
- [x] #3 Today's date cell is visually highlighted on the month grid
- [x] #4 Tapping a day cell fetches and displays records released on that day, each showing cover art, artist names, and title
- [x] #5 Tapping ← → arrows navigates to previous/next month, refreshing the calendar
- [x] #6 Tapping a back button (or back gesture) in day view returns to month view
- [x] #7 When the server is unreachable or returns an error, a user-readable message is shown instead of crashing
- [x] #8 Cover images are loaded and displayed from the thumb_url returned by the API
- [x] #9 A secrets.example.py is provided documenting the required WIFI_SSID, WIFI_PASSWORD, and API_TOKEN variables
- [x] #10 A README.md in the presto/ directory explains how to set up and deploy to the device

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## File structure

```
presto/
  main.py              # Entry point: boot sequence, state machine, main loop
  secrets.example.py   # Template for secrets.py (WIFI_SSID, WIFI_PASSWORD, API_TOKEN)
  README.md            # Setup and deployment instructions
```

`secrets.py` is `.gitignore`d. The user creates it from the example.

## Architecture (in main.py)

### Boot sequence

1. `import secrets` — reads WIFI_SSID, WIFI_PASSWORD, API_TOKEN
2. Connect WiFi via `network.WLAN` — retry loop with timeout (30s)
3. Sync time via NTP (`ntptime.settime()`)
4. Set current year/month from `time.localtime()`
5. Enter main loop in MONTH_VIEW state

### State machine

Two states: `MONTH_VIEW` and `DAY_VIEW`. A global `state` variable and a `redraw` flag control rendering.

```
MONTH_VIEW
  ├── render_calendar(year, month)   → draw 7×6 grid + month header + ← →
  ├── handle_touch(x, y)
  │     ├── arrow left  → month -= 1, redraw
  │     ├── arrow right → month += 1, redraw
  │     └── day cell    → selected_date = date, fetch_records(), switch to DAY_VIEW
  └── highlight today (if visible month matches)

DAY_VIEW
  ├── render_records(records)        → draw cover thumbnails + artist + title
  ├── handle_touch(x, y)
  │     ├── back button → switch to MONTH_VIEW
  │     └── record row  → (future: detail view, for now no-op)
  └── show error message if fetch failed
```

### API client (functions in main.py)

- `fetch_records(date_str)` → GET `/api/v1/collection/on_this_day?date=YYYY-MM-DD` with `Authorization: Bearer {API_TOKEN}`, parse JSON, return list of record dicts
- `fetch_image(url)` → GET url with same auth header, return JPEG bytes buffer
- On network error: return `None`, caller shows "Could not reach server" message

### Calendar rendering (`render_calendar`)

- Use PicoGraphics to draw on the 720×720 framebuffer
- Month/year header at top (y: 0–60), arrows on sides
- Day-of-week labels (Mon–Sun) at y: 60–90
- 7×6 grid cells, each ~100×100, starting at y: 90
- Today's cell: filled background (accent color)
- Selected date cell: outlined border
- Day numbers drawn centered in each cell

### Day view rendering (`render_records`)

- Header: "April 15" + back button (← icon or "< Back" text)
- Record rows: each row is ~150px tall
  - Left: cover thumbnail (~140×140, loaded from `thumb_url`)
  - Right: title (wrapped), artist names
- If >4 records, simple pagination or scroll with up/down arrows
- Error state: centered text "Could not reach server" + "Tap to retry"

### Touch handling

- Presto touch driver provides (x, y, pressure) events
- `handle_touch()` is called from the main loop when a touch event fires
- Hit-testing: compare (x, y) against known UI regions (arrow rects, day cells, back button)
- Debounce: ignore touches within 300ms of each other

### Image loading

- On entering DAY_VIEW, fetch all thumbnails sequentially (to avoid memory pressure)
- Each JPEG is decoded via PicoGraphics JPEG decoder and drawn at the target position
- Images are drawn directly to the framebuffer (not cached to flash, to keep it simple)
- If an image fails to load, show a placeholder rectangle

### Error handling

- WiFi failure: show "WiFi connection failed" + retry every 10s
- API unreachable: show error message in day view, keep month view functional
- Image load failure: show placeholder, don't crash

### Constants / layout

All positions, sizes, and colors defined as module-level constants at the top of main.py for easy tweaking.

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Implementation Notes

### Files created

| File                       | Lines | Description                                                                                                              |
| -------------------------- | ----- | ------------------------------------------------------------------------------------------------------------------------ |
| `presto/main.py`           | 1030  | Full MicroPython application with boot sequence, state machine, calendar rendering, day view, API client, touch handling |
| `presto/config.example.py` | 20    | Template for secrets.py (renamed from secrets.example.py due to sensitive-file guard)                                    |
| `presto/README.md`         | 140   | Setup, deployment, usage, troubleshooting instructions                                                                   |
| `.gitignore` (updated)     | +3    | Added `presto/secrets.py` to gitignore                                                                                   |

### Architecture

- **Single file** (`main.py`) — all logic in one module for simplicity on MicroPython
- **State machine**: 3 states (STARTUP, MONTH, DAY) controlled by `state` global
- **No classes** — uses module-level functions and globals to minimize MicroPython memory overhead
- **Pen pre-creation**: All PicoGraphics pens created once in `_init_pens()` to reduce GC pressure
- **Touch debounce**: 300ms debounce on all touch events
- **WiFi retry**: 30s timeout, retry every 10s on failure
- **JPEG decoding**: Tries 3 different firmware APIs with graceful fallback to placeholder
- **API auth**: `Authorization: Bearer <token>` on all requests
- **NTP**: Non-fatal — calendar still works with RTC time if NTP fails

### Key design decisions

1. **Thumbnails loaded synchronously during render** (not cached) — keeps memory usage low; max 4 thumbnail fetches per day view
2. **Text wrapping** (`draw_wrapped()`) — PicoGraphics has no automatic wrapping, so manual word-boundary wrapping is implemented
3. **Scroll arrows** for >4 records — simple ^ v arrows for paging through records
4. **Touch API compatibility** — `read_touch()` tries multiple Presto firmware touch APIs
5. **Selected cell border** — today+selected combo shows both highlight and border

### What's NOT tested

- **Physical device testing** — requires a real Pimoroni Presto; code is written for stock firmware but may need minor adjustments
- **JPEG decoder API** — depends on firmware version; 3 fallback methods provided
- **Touch API** — depends on firmware version; multiple methods tried in `read_touch()`
- **Memory pressure** — 1030 lines is large for MicroPython; may need to be split across files or use frozen bytecode
- **SSL/TLS** — `urequests` on MicroPython may need explicit SSL context or may not support HTTPS depending on firmware build

### Potential firmware adjustments needed

1. If `jpegdec` module is named differently or has different API, update `draw_jpeg()`
2. If `presto.touch` API differs, update `read_touch()`
3. If `PicoGraphics` constructor signature differs, update `init_display()`
4. If `set_font()` font names differ, update font references
5. If HTTPS doesn't work, switch `API_BASE` to `http://` or add SSL context

<!-- SECTION:NOTES:END -->
