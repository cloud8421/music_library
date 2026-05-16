# Presto Music Library

MicroPython app for the [Pimoroni Presto](https://shop.pimoroni.com/products/presto?variant=54894104019323) that connects to the Music Library API. It runs full-resolution on the 480x480 touch display and lets you search the collection or browse records released on a selected date.

## What It Does

- Home screen with **Search Collection** and **Today's Records**
- Month calendar with day navigation and today's date highlighted
- Day list with cover art, title, artists, format, and release year
- Search input with on-screen keyboard and scrollable results
- Record detail page with larger cover art, genres, metadata, purchase date, and optional Last.fm scrobble button
- Display sleep after 1 minute of inactivity, with wake-on-touch
- WiFi reconnect, NTP sync, and simple network error states

## Requirements

- Pimoroni Presto running stock firmware with MicroPython, PicoGraphics, touch, `urequests`, `ntptime`, and usually `jpegdec`
- WiFi with internet access
- Music Library API token

## Setup

Create `secrets.py` from the template:

```bash
cp config.example.py secrets.py
```

Fill in:

```python
WIFI_SSID = "your-wifi-ssid"
WIFI_PASSWORD = "your-wifi-password"
API_TOKEN = "your-api-token"
```

`secrets.py` is git-ignored and must not be committed.

## Deploy

First-time deployment needs both the app and credentials on the device:

```bash
mpremote fs cp main.py :main.py
mpremote fs cp secrets.py :secrets.py
mpremote reset
```

After `secrets.py` has been copied once, use the project task:

```bash
mise run presto
```

That task copies `main.py` to `:main.py` and resets the Presto. It does not copy `secrets.py`.

The Presto runs `main.py` on boot, connects to WiFi, syncs time, then opens the home screen.

## Usage

**Home:** tap **Search Collection** to search by text, or **Today's Records** to open the current month with today highlighted.

**Month view:** use the arrow buttons to change month, tap a day to load records released on that date, or tap **H** to return home.

**Day view:** drag vertically to scroll long lists. During drag scrolling, covers are drawn as placeholders and restored when the drag ends. Tap a row to open its detail page.

**Search:** type with the on-screen keyboard and tap **OK**. Results use the same row and detail views as the day list. Back from results returns to the search input with the query preserved.

**Record detail:** shows title, artists, medium cover, genres, record type, format, release year, and purchase date. Records with `selected_release_id` show a **Scrobble** button; successful scrobbles show **Done** until you leave the detail page.

**Display sleep:** after 1 minute without touch input, the backlight turns off. The first touch wakes the display and is consumed so it does not also press a button or start a scroll.

## Testing

Run the headless smoke tests from this directory:

```bash
mise run test
```

The tests use `pimoroni-emulator` mock MicroPython modules, import `main.py` without starting the event loop, and block accidental network calls. They render all screen states and save screenshots to `tests/fixtures/` for manual inspection.

For a syntax-only check without creating `__pycache__`:

```bash
python3 -c "import py_compile; py_compile.compile('main.py', cfile='/tmp/main.pyc', doraise=True)"
```

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `secrets.py not found` | Credentials are missing on the device | Copy `secrets.py` to the Presto root |
| `WIFI_SSID not set` or `API_TOKEN not set` | Required value is blank | Check `secrets.py` |
| `WiFi connection failed` | Wrong credentials or network unavailable | Verify SSID, password, and network |
| `Could not reach server` | API token invalid, server down, or network lost | Check `API_TOKEN` and server status |
| Grey cover placeholders | JPEG decoder unavailable or image URL failed | Check firmware and internet access |
| Black display after idle | Display sleep is active | Touch once to wake |

## API Contract

All requests use:

```http
Authorization: Bearer <API_TOKEN>
```

The app calls:

```http
GET /api/v1/collection/on_this_day?date=YYYY-MM-DD
GET /api/v1/collection?q=QUERY&limit=20
POST /api/v1/collection/:record_id/scrobble
```

Both `GET` endpoints return `{ "records": [...] }`. Fields used by the client:

- `id`
- `selected_release_id`
- `title`
- `artists`
- `format`
- `release_date`
- `genres`
- `record_type`
- `purchased_at`
- `covers.small`
- `covers.medium`

The day and search lists use `covers.small` as an 80x80 row thumbnail. Detail pages use `covers.medium` in a 400x400 cover area. The app expects display-ready JPEGs and does not resize covers on the device.

## License

This application is part of the Music Library project.
