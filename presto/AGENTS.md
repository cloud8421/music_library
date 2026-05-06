# Presto App Guidance

This directory contains MicroPython apps for the Pimoroni Presto. The main app is
`records_on_the_day.py`, deployed to the device as `main.py`.

## Context To Read First

- Read `README.md` before changing setup, deployment, user-facing behavior, or API response assumptions.
- Read `records_on_the_day.py` before changing layout, touch handling, networking, display sleep, or performance-sensitive code.
- The root project conventions still apply, but most Phoenix/Elixir conventions are not relevant inside `presto/`.

## Deployment And Verification

- The project task deploys the records app:

  ```bash
  mise run presto
  ```

- Manual deployment copies `records_on_the_day.py` to the device as `main.py`:

  ```bash
  mpremote fs cp records_on_the_day.py :main.py
  mpremote fs cp secrets.py :secrets.py
  mpremote reset
  ```

- Before finishing Python edits, run a syntax-only check that does not leave `__pycache__` behind:

  ```bash
  python3 -c "import py_compile; py_compile.compile('records_on_the_day.py', cfile='/tmp/records_on_the_day.pyc', doraise=True)"
  ```

- Do not claim device behavior is verified unless it was tested on the physical Presto.

## Hardware And Runtime Constraints

- Target stock Pimoroni Presto firmware: MicroPython, PicoGraphics, touch driver, `urequests`, `ntptime`, and usually `jpegdec`.
- Presto hardware is RP2350B, but stock firmware should be treated as a single Python runtime. Do not assume `_thread` or user-accessible multicore support.
- Keep memory pressure low. Avoid large in-memory image buffers, aggressive caching of large responses, and repeated `gc.collect()` in hot render paths.
- Network calls are blocking. Avoid doing HTTP requests during drag scrolling or repeated redraw loops.

## Records App Behavior

- Boot should land on today's records, not the month calendar.
- The Back button returns from day view to month view.
- Month and day headers should share the same header geometry: height, button dimensions, side margins, and centered title/date positioning.
- Day rows show cover art, title, artists, and a dim metadata line of `format | year`.
- `release_date` is displayed as year only.
- Text shown with bitmap fonts should pass through `display_text()` to replace unsupported punctuation such as smart dashes and quotes. Do not strip diacritics; the font can render them.

## Image Handling

- Prefer `micro_cover_url`, then `mini_cover_url`, then `thumb_url`.
- Keep `THUMB_SIZE` aligned with the micro image size when possible.
- Cache downloaded thumbnail bytes on the record dict as `_thumb_data`.
- Keep the placeholder-while-dragging behavior. Decoding JPEGs during drag was too slow on device, even with micro covers.
- Repaint real covers after the finger is released.
- Do not call `gc.collect()` per row draw. Collect after record preparation, after API fetches, or at other non-hot-path points.
- JPEG is the practical default on stock firmware. PNG generally has worse memory characteristics, and raw/RGB565 should only be attempted after confirming a stable on-device blit API.

## Scroll Performance

- The scroll hot path must not measure text, join artist lists, sanitize strings, calculate full content height, or fetch images.
- After fetching records, call the preparation path that caches:
  - `_display_title`
  - `_display_artists`
  - `_display_meta`
  - `_thumb_url`
  - `_row_height`
  - total `_content_height`
- Preload only `micro_cover_url` thumbnails before the first day-view draw. Do not eagerly fetch larger fallback images.
- Drag scrolling should remain pixel-based, but redraws should be throttled by both time and pixel delta (`DRAG_REDRAW_MS`, `DRAG_REDRAW_PX`).
- Preserve any pending drag delta on touch release and redraw once with real covers if the view moved.

## Layout Details

- Use named constants for pixel geometry instead of scattered literals.
- For record rows, keep cover top and bottom spacing visually symmetric:
  - `ROW_PAD_Y` is the padding above and below the cover.
  - `ROW_SEPARATOR_H` is the separator line height after the bottom padding.
- If row spacing looks wrong on device, reason in terms of inclusive pixel drawing: a separator drawn inside the padding visually consumes that padding.

## Display Sleep

- The display sleeps by setting the backlight to `0.0`; the app and WiFi stay running.
- The first touch after sleep should wake the backlight and be consumed so it does not also activate a control.
- On wake, check WiFi and reconnect only if it dropped.

## API Contract

The records endpoint is:

```text
GET https://music-library.claudio-ortolina.org/api/v1/collection/on_this_day?date=YYYY-MM-DD
Authorization: Bearer <API_TOKEN>
```

Expected record fields used by the app:

- `title`
- `artists`
- `format`
- `release_date`
- `micro_cover_url`
- `mini_cover_url`
- `thumb_url`

When adding or changing API assumptions, update `README.md`.
