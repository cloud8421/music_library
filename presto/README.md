# Presto Music Library - Records On This Day

A MicroPython application for the [Pimoroni Presto](https://shop.pimoroni.com/products/presto?variant=54894104019323) (RP2350B, 720×720 touch display, WiFi) that connects to the Music Library API and lets you browse your record collection by release date.

## Features

- **Month calendar** — 7×6 grid with day-of-week headers, today highlight
- **Tap a day** — see records released on that date with cover art, titles, and artist names
- **Month navigation** — arrow buttons to browse previous/future months
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

**Using Thonny:**

1. Open Thonny and select "MicroPython (Raspberry Pi Pico)" as the interpreter
2. Open `main.py` and `secrets.py` in Thonny
3. Use File → Save Copy → Raspberry Pi Pico to save each file to the device
4. Press the reset button on the Presto, or use Run → Send EOF / Soft Reboot

### 3. The app starts automatically

The Presto runs `main.py` on boot. The app will:
1. Show a startup screen
2. Connect to WiFi (showing progress)
3. Sync time via NTP
4. Display the current month calendar

## Usage

### Month view

- **Today's date** is highlighted in blue
- Tap **← →** arrows to navigate months
- Tap any **day cell** to see records released on that date

### Day view

- Shows up to 4 records per screen with **cover art**, **title**, and **artists**
- Tap **< Back** to return to the month view
- If there are more than 4 records, use **^ v** arrows to scroll

### Error states

- **"Could not reach server"** — the API is unreachable. Tap anywhere on the day view to retry, or tap Back to return to the month view.
- **"WiFi connection failed"** — WiFi credentials are wrong or the network is down. The app retries every 10 seconds.
- **Grey placeholder** in place of cover art — the image could not be loaded (network issue or invalid URL). The rest of the record info is still shown.

## Files

```
presto/
  main.py              # Application entry point (auto-runs on boot)
  config.example.py    # Template for secrets.py
  secrets.py           # Your credentials (git-ignored, create from example)
  README.md            # This file
```

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|-------------|-----|
| Stuck on "secrets.py not found" | `secrets.py` not on the device | Copy `config.example.py` to `secrets.py` and deploy it |
| Stuck on "WiFi connection failed" | Wrong SSID/password, or network down | Check `secrets.py` credentials; verify network is up |
| "Could not reach server" on day tap | API token invalid, or server down | Check `API_TOKEN` in `secrets.py`; verify the server is running |
| Images show as grey rectangles | JPEG decoder not available, or image URLs unreachable | Check firmware version; ensure Presto has internet access |
| Touch not responding | Firmware touch API mismatch | Try updating Presto firmware to the latest version |

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
      "thumb_url": "https://.../api/v1/assets/thumb.jpg?width=480",
      "release_date": "1973-03-01",
      "genres": ["Rock"],
      "format": "Vinyl"
    }
  ]
}
```

## License

This application is part of the Music Library project.
