# Presto App Guidance

This directory contains MicroPython apps for the Pimoroni Presto. The main app is
`records_on_the_day.py`, deployed to the device as `main.py`.

## Context To Read First

- Read `README.md` before changing setup, deployment, user-facing behavior, or API response assumptions.
- Read `records_on_the_day.py` before changing layout, touch handling, networking, display sleep, or performance-sensitive code.
- The root project conventions still apply, but most Phoenix/Elixir conventions are not relevant inside `presto/`.

## Deployment And Verification

```bash
mise run presto                     # deploy and reset
```

Manual deployment:

```bash
mpremote fs cp records_on_the_day.py :main.py
mpremote fs cp secrets.py :secrets.py
mpremote reset
```

Syntax check (no `__pycache__`):

```bash
python3 -c "import py_compile; py_compile.compile('records_on_the_day.py', cfile='/tmp/records_on_the_day.pyc', doraise=True)"
```

Do not claim device behavior is verified unless it was tested on the physical Presto.

## Hardware And Runtime Constraints

- Stock Presto firmware: MicroPython, PicoGraphics, touch driver, `urequests`, `ntptime`, usually `jpegdec`.
- Treat as single-threaded. Do not assume `_thread` or user-accessible multicore.
- Keep memory pressure low: no large in-memory buffers, no aggressive response caching, no `gc.collect()` in hot render paths.
- Network calls (`urequests`) are blocking. Never make HTTP requests during drag scrolling or inside repeated redraw loops.

## State Management

- Every view state (`STATE_STARTUP`, `STATE_MONTH`, `STATE_DAY`, `STATE_RECORD`) must be handled in `redraw_current_view()` for correct display sleep/wake.
- When transitioning into a view, reset its scroll offset to 0 so it always starts at the top.
- When adding a new state, update `main()` globals, `redraw_current_view()`, the main loop dispatch, and any related state cleanup on navigation.

## Scroll Performance

_These rules apply to any scrollable view (day list, detail page, or future additions)._

- The scroll hot path must not: measure text, join strings, sanitize text, compute layout heights, or fetch images over the network.
- Pre-compute and cache all display strings and dimensions after data arrives and before the first draw.
- Throttle drag redraws by both time (`DRAG_REDRAW_MS`) and pixel delta (`DRAG_REDRAW_PX`). Preserve pending delta on touch release and redraw once.
- Each scrollable view gets its own offset variable and its own content-height cache. Never reuse one view's scroll state for another.
- If the view has a fixed header, use `display.set_clip()` / `display.remove_clip()` to prevent scrollable content from drawing over it.

## Image Handling

- Row thumbnails prefer `micro_cover_url` → `mini_cover_url` → `thumb_url`. Detail/large cover prefers `thumb_url` → `mini_cover_url` → `micro_cover_url`.
- Cache downloaded image bytes on the record dict. Use separate cache keys for different sizes (e.g., `_thumb_data` for rows, `_detail_thumb_data` for detail view). Never fetch images during drag — show placeholders instead and repaint real covers on release.
- JPEG is the practical default. PNG has worse memory characteristics; raw/RGB565 needs a confirmed stable blit API on the target firmware.

## Text Rendering

- All user-visible text shown with bitmap fonts must pass through `display_text()` to replace unsupported punctuation (smart quotes, dashes, ellipsis). Do not strip diacritics — the font can render them.
- `release_date` is displayed as year only (first 4 characters).

## Layout

- Use named constants for all pixel geometry. No scattered literals.
- Keep header geometry consistent across views: same height, button dimensions, and side margins.

## Display Sleep

- Sleep by setting backlight to `0.0`. WiFi stays enabled.
- The first touch after sleep must wake the backlight and be consumed — it must not also activate a button or trigger a scroll.
- On wake, `set_today()` refreshes the global date from the system clock, WiFi is reconnected if it dropped, and the current view is always redrawn so the today-highlight stays current across midnight.

## API Contract

```
GET https://music-library.claudio-ortolina.org/api/v1/collection/on_this_day?date=YYYY-MM-DD
Authorization: Bearer <API_TOKEN>
```

Fields used by the app: `title`, `artists`, `format`, `release_date`, `genres`, `record_type`, `purchased_at`, `micro_cover_url`, `mini_cover_url`, `thumb_url`.

When adding or changing API assumptions, update `README.md`.
