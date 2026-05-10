# Presto Music Library - Records On This Day

A MicroPython application for the [Pimoroni Presto](https://shop.pimoroni.com/products/presto?variant=54894104019323) (RP2350B, 720×720 touch display, WiFi) that connects to the Music Library API and lets you browse your record collection by release date.

## Features

- **Month calendar** — 7×6 grid with day-of-week headers, today highlight
- **Today's records on boot** — opens directly to records released on today's date
- **Tap a day** — see records released on that date with cover art, titles, artist names, format, and release year
- **Record detail view** — tap any record row to see large cover art, genres, record type, and purchase date
- **Month navigation** — arrow buttons to browse previous/future months
- **Touch scrolling** — drag the day view to scroll through longer record lists
- **Display sleep** — turns the backlight off after 1 minute of inactivity and wakes on touch
- **WiFi auto-connect** — connects on boot with retry logic
- **NTP time sync** — calendar always shows the correct date
- **Error handling** — graceful messages when the server is unreachable or images fail to load

## Requirements

- Pimoroni Presto running stock firmware (MicroPython + PicoGraphics + touch driver)
- WiFi network with internet access
- A valid API token for the Music Library API

## Setup

### 1. Create secrets.py

```bash
cp config.example.py secrets.py
```

Edit `secrets.py` and fill in your credentials:

```python
WIFI_SSID = "your-wifi-ssid"
WIFI_PASSWORD = "your-wifi-password"
API_TOKEN = "your-api-token"
```

> `secrets.py` is git-ignored and never committed.

### 2. Deploy to your Presto

Copy the files to the root of your Presto's flash storage. You can use Thonny, `mpremote`, or any MicroPython file transfer tool.

**Using `mpremote`:**

```bash
# Install mpremote if you don't have it
pip install mpremote

# Copy files to the Presto
mpremote fs cp main.py :main.py
mpremote fs cp secrets.py :secrets.py

# Reset the device to start the app
mpremote reset
```

After `secrets.py` has been copied to the device once, you can redeploy the app with the project task:

```bash
mise run presto
```

This copies `main.py` to `:main.py` and resets the device; it does not copy `secrets.py`.

**Using Thonny:**

1. Open Thonny and select "MicroPython (Raspberry Pi Pico)" as the interpreter
2. Open `main.py` and `secrets.py` in Thonny
3. Use File → Save Copy → Raspberry Pi Pico to save `main.py` as `main.py` and `secrets.py` as `secrets.py`
4. Press the reset button on the Presto, or use Run → Send EOF / Soft Reboot

### 3. The app starts automatically

The Presto runs `main.py` on boot. The app will:

1. Show a startup screen
2. Connect to WiFi (showing progress)
3. Sync time via NTP
4. Load and display today's records

## Usage

### Month view

- **Today's date** is highlighted in blue
- Tap **← →** arrows to navigate months
- Tap any **day cell** to see records released on that date

### Day view

- Shows records with **cover art**, **title**, **artists**, **format**, and **release year**
- Tap **< Back** to return to the month view
- Drag vertically to scroll through longer lists
- During drag scrolling, cover art is temporarily shown as lightweight placeholders and redrawn when you lift your finger

### Record detail view

- Tap any **record row** in the day view to open its detail page
- Shows a **larger cover image** (uses `thumb_url`, 480px source), the full title, artists, genres, record type, format, release year, and purchase date
- Drag vertically to scroll if the content is taller than the screen
- The header bar stays fixed at the top while the cover and info scroll underneath
- Tap **< Back** to return to the day view

### Display sleep

- After 1 minute with no touch input, the display backlight turns off
- Touch the screen once to wake it; the wake touch is ignored so it will not also press a button or scroll
- WiFi is left enabled while the display sleeps. If it drops while idle, the app reconnects on wake

### Error states

- **"Could not reach server"** — the API is unreachable. Tap anywhere on the day view to retry, or tap Back to return to the month view.
- **"WiFi connection failed"** — WiFi credentials are wrong or the network is down. The app retries every 10 seconds.
- **Grey placeholder** in place of cover art — the image could not be loaded (network issue or invalid URL). The rest of the record info is still shown.

## Files

```
presto/
  main.py # Application source, deployed to the device as main.py
  config.example.py     # Template for secrets.py
  secrets.py            # Your credentials (git-ignored, create from example)
  README.md             # This file
```

## Troubleshooting

| Symptom                             | Likely cause                                          | Fix                                                             |
| ----------------------------------- | ----------------------------------------------------- | --------------------------------------------------------------- |
| Stuck on "secrets.py not found"     | `secrets.py` not on the device                        | Copy `config.example.py` to `secrets.py` and deploy it          |
| Stuck on "WiFi connection failed"   | Wrong SSID/password, or network down                  | Check `secrets.py` credentials; verify network is up            |
| "Could not reach server" on day tap | API token invalid, or server down                     | Check `API_TOKEN` in `secrets.py`; verify the server is running |
| Images show as grey rectangles      | JPEG decoder not available, or image URLs unreachable | Check firmware version; ensure Presto has internet access       |
| Touch not responding                | Firmware touch API mismatch                           | Try updating Presto firmware to the latest version              |
| Display is black after idle         | Backlight sleep is active                             | Touch once to wake the display                                  |

## API Endpoint

The app talks to:

```
GET https://music-library.claudio-ortolina.org/api/v1/collection/on_this_day?date=YYYY-MM-DD
Authorization: Bearer <API_TOKEN>
```

Response format:

```json
{
  "records": [
    {
      "id": "...",
      "title": "Album Title",
      "artists": ["Artist Name"],
      "micro_cover_url": "https://.../api/v1/assets/thumb.jpg?width=40",
      "mini_cover_url": "https://.../api/v1/assets/thumb.jpg?width=150",
      "thumb_url": "https://.../api/v1/assets/thumb.jpg?width=480",
      "release_date": "1973-03-01",
      "genres": ["Rock"],
      "format": "Vinyl",
      "record_type": "LP",
      "purchased_at": "2024-11-15"
    }
  ]
}
```

The Presto client prefers `micro_cover_url` for the 40×40 row thumbnail, then falls back to `mini_cover_url` and `thumb_url`.
The detail view prefers `thumb_url` for the full-size cover, falling back to `mini_cover_url` and `micro_cover_url`.

## License

This application is part of the Music Library project.
