"""
Presto Music Library - Records On This Day Calendar
===================================================
A MicroPython application for the Pimoroni Presto (RP2350B, 720x720 touch
display, WiFi) that connects to the Music Library API and lets you browse
records by release date.

Features:
  - WiFi auto-connect with retry
  - NTP time synchronisation
  - Month calendar view with day-of-week headers
  - Tap a day to see records released on that date (cover art, artist, title)
  - Navigate months with arrow buttons
  - Error handling for network / API failures

Hardware: Pimoroni Presto running stock Presto firmware
  (MicroPython + PicoGraphics + touch driver)

Setup:
  1. Copy config.example.py to secrets.py and fill in your credentials
  2. Copy main.py and secrets.py to the root of your Presto's flash
  3. The app starts automatically on boot (main.py is the default entry point)
"""

# ============================================================================
# IMPORTS
# ============================================================================

import gc
import json
import time
import network
import ntptime

import urequests

# Presto hardware module (provided by stock firmware)
from presto import Presto

# JPEG decoder (provided by stock firmware; may be named jpegdec or picographics
# depending on firmware version — adjust import if needed)
try:
    import jpegdec as _jpegdec_lib
    _HAS_JPEGDEC = True
except ImportError:
    _HAS_JPEGDEC = False

# ============================================================================
# CONFIGURATION
# ============================================================================

# API endpoint (production server)
API_BASE = "https://music-library.claudio-ortolina.org"

# Setup for the Presto display
presto = Presto()
display = presto.display
WIDTH, HEIGHT = display.get_bounds()
touch = presto.touch

# Calendar layout (computed from display bounds)
CELL_GAP = 3
CELLS_PER_ROW = 7
MAX_ROWS = 6

# Header
HEADER_Y = 0
HEADER_H = 46
MONTH_Y = HEADER_Y + 6
ARROW_W = 48
ARROW_H = 34

# Day-of-week labels
DOW_Y = HEADER_Y + HEADER_H + 2
DOW_H = 16

# Day cells: fit 7 across with comfortable side margins
CELL_SIZE = (WIDTH - 16 - (CELLS_PER_ROW - 1) * CELL_GAP) // CELLS_PER_ROW
if CELL_SIZE > 78:
    CELL_SIZE = 78
GRID_LEFT = (WIDTH - (CELLS_PER_ROW * CELL_SIZE + (CELLS_PER_ROW - 1) * CELL_GAP)) // 2

# Grid starts after day-of-week labels with a small gap
CALENDAR_TOP = DOW_Y + DOW_H + 6

# Day view (proportional to cell size)
BACK_X = 8
BACK_Y = 8
BACK_W = 44
BACK_H = 32
RECORD_START_Y = BACK_Y + BACK_H + 12
THUMB_SIZE = 75
THUMB_MARGIN = 8
TEXT_X = THUMB_MARGIN + THUMB_SIZE + 12
TEXT_W = WIDTH - TEXT_X - 12

# Colors (RGB tuples, converted to pens at runtime)
BG = (22, 22, 36)
CELL_BG = (48, 48, 66)
CELL_OTHER_MONTH = (35, 35, 50)
TODAY_BG = (50, 90, 175)
TODAY_TEXT = (255, 255, 255)
NORMAL_TEXT = (215, 215, 235)
DIM_TEXT = (125, 125, 150)
HEADER_TEXT = (240, 240, 255)
ARROW_COLOR = (185, 185, 210)
BACK_COLOR = (210, 210, 235)
TITLE_COLOR = (240, 240, 255)
ARTIST_COLOR = (190, 190, 215)
ERROR_COLOR = (255, 115, 115)
PLACEHOLDER_BG = (65, 65, 85)
STATUS_TEXT = (170, 170, 195)

# Days of week (Monday first, ISO 8601)
DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
MONTH_NAMES = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
]

# Touch debounce (milliseconds)
DEBOUNCE_MS = 300

# WiFi connection timeout (seconds)
WIFI_TIMEOUT = 30

# ============================================================================
# GLOBAL STATE
# ============================================================================

api_token = ""

# Time state
today_year = 2026
today_month = 5
today_day = 1
view_year = 2026
view_month = 5

# View state
STATE_STARTUP = 0
STATE_MONTH = 1
STATE_DAY = 2
STATE_ERROR = 3
state = STATE_STARTUP

# Day view state
selected_day = 0           # 1-based day of month
records = []               # List of record dicts from API
records_error = False      # True if API call failed
# Scroll state
scroll_offset = 0          # Scroll position for day view
_visible_count = 1         # How many records fit on screen (set during draw)

# Touch debounce
_last_touch = 0

# ============================================================================
# HELPER: PEN CREATION
# ============================================================================

# We create pens once and reuse them to reduce GC pressure.
# Stored as module-level variables, initialised in init_display().

_pen_bg = None
_pen_cell_bg = None
_pen_cell_other = None
_pen_today_bg = None
_pen_today_text = None
_pen_normal_text = None
_pen_dim_text = None
_pen_header_text = None
_pen_arrow = None
_pen_back = None
_pen_title = None
_pen_artist = None
_pen_error = None
_pen_placeholder = None
_pen_status = None


def _init_pens():
    """Pre-create all pens from the RGB color constants."""
    global _pen_bg, _pen_cell_bg, _pen_cell_other, _pen_today_bg
    global _pen_today_text, _pen_normal_text, _pen_dim_text, _pen_header_text
    global _pen_arrow, _pen_back, _pen_title, _pen_artist, _pen_error
    global _pen_placeholder, _pen_status

    _pen_bg = display.create_pen(*BG)
    _pen_cell_bg = display.create_pen(*CELL_BG)
    _pen_cell_other = display.create_pen(*CELL_OTHER_MONTH)
    _pen_today_bg = display.create_pen(*TODAY_BG)
    _pen_today_text = display.create_pen(*TODAY_TEXT)
    _pen_normal_text = display.create_pen(*NORMAL_TEXT)
    _pen_dim_text = display.create_pen(*DIM_TEXT)
    _pen_header_text = display.create_pen(*HEADER_TEXT)
    _pen_arrow = display.create_pen(*ARROW_COLOR)
    _pen_back = display.create_pen(*BACK_COLOR)
    _pen_title = display.create_pen(*TITLE_COLOR)
    _pen_artist = display.create_pen(*ARTIST_COLOR)
    _pen_error = display.create_pen(*ERROR_COLOR)
    _pen_placeholder = display.create_pen(*PLACEHOLDER_BG)
    _pen_status = display.create_pen(*STATUS_TEXT)


# ============================================================================
# HELPER: TEXT WRAPPING
# ============================================================================

def draw_wrapped(text, x, y, max_width, pen, scale=1):
    """Draw text, wrapping at word boundaries to fit within max_width pixels.

    PicoGraphics doesn't support automatic wrapping, so we manually break
    long strings. Returns the Y position after the last line drawn.
    """
    words = text.split(" ")
    lines = []
    current_line = ""

    for word in words:
        test_line = current_line + (" " if current_line else "") + word
        w = display.measure_text(test_line, scale=scale)
        if w <= max_width:
            current_line = test_line
        else:
            if current_line:
                lines.append(current_line)
            # If a single word is too long, we draw it anyway (truncation
            # would hide information).
            if display.measure_text(word, scale=scale) > max_width:
                lines.append(word)
                current_line = ""
            else:
                current_line = word

    if current_line:
        lines.append(current_line)

    line_height = 8 * scale + 4  # bitmap8 is 8px tall, plus spacing
    cy = y
    display.set_pen(pen)
    for line in lines:
        display.text(line, x, cy, scale=scale)
        cy += line_height

    return cy


# ============================================================================
# HELPER: DATE / CALENDAR MATH
# ============================================================================

def days_in_month(year, month):
    """Return the number of days in the given month."""
    if month == 2:
        # Leap year check
        if (year % 4 == 0 and year % 100 != 0) or (year % 400 == 0):
            return 29
        return 28
    if month in (4, 6, 9, 11):
        return 30
    return 31


def day_of_week(year, month, day):
    """Return 0=Monday .. 6=Sunday using Zeller-like algorithm adjusted
    for our calendar (Monday-first weeks)."""
    # Tomohiko Sakamoto's algorithm, adjusted for Monday=0
    t = [0, 3, 2, 5, 0, 3, 5, 1, 4, 6, 2, 4]
    y = year - (1 if month < 3 else 0)
    d = (y + y // 4 - y // 100 + y // 400 + t[month - 1] + day) % 7
    # Convert Sunday=0 to Sunday=6, Monday=1 to Monday=0, etc.
    return (d + 6) % 7


def previous_month(year, month):
    """Return (year, month) for the previous month."""
    if month == 1:
        return year - 1, 12
    return year, month - 1


def next_month(year, month):
    """Return (year, month) for the next month."""
    if month == 12:
        return year + 1, 1
    return year, month + 1


# ============================================================================
# NETWORKING
# ============================================================================

def connect_wifi():
    """Connect to WiFi using credentials from secrets.py.

    Returns True on success, False on failure.
    Blinks status messages on the display during the attempt.
    """
    try:
        import secrets
    except ImportError:
        draw_status("ERROR: secrets.py not found.\n"
                     "Copy config.example.py to secrets.py")
        return False

    ssid = getattr(secrets, "WIFI_SSID", "")
    password = getattr(secrets, "WIFI_PASSWORD", "")
    global api_token
    api_token = getattr(secrets, "API_TOKEN", "")

    if not ssid:
        draw_status("ERROR: WIFI_SSID not set in secrets.py")
        return False
    if not api_token:
        draw_status("ERROR: API_TOKEN not set in secrets.py")
        return False

    draw_status("Connecting to WiFi:\n{}".format(ssid))

    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)

    if wlan.isconnected():
        draw_status("Already connected.\nSyncing time...")
        return True

    wlan.connect(ssid, password)

    # Wait for connection with timeout
    elapsed = 0
    while not wlan.isconnected() and elapsed < WIFI_TIMEOUT:
        time.sleep(0.5)
        elapsed += 0.5

    if wlan.isconnected():
        ip = wlan.ifconfig()[0]
        draw_status("Connected.\nIP: {}\nSyncing time...".format(ip))
        return True
    else:
        draw_status("WiFi connection failed.\n"
                     "Check credentials.\n"
                     "Retrying in 10 seconds...")
        return False


def sync_time():
    """Synchronise system time via NTP. Non-fatal on failure."""
    try:
        ntptime.settime()
    except Exception:
        # NTP failure is non-fatal; calendar still works (shows RTC time)
        pass


def set_today():
    """Read current date from system clock into global today_* vars."""
    global today_year, today_month, today_day
    lt = time.localtime()
    today_year = lt[0]
    today_month = lt[1]
    today_day = lt[2]


def make_date_string(year, month, day):
    """Format a date as YYYY-MM-DD for the API."""
    return "{:04d}-{:02d}-{:02d}".format(year, month, day)


# ============================================================================
# API CLIENT
# ============================================================================

def _auth_header():
    """Return the Authorization header dict for urequests."""
    return {"Authorization": "Bearer " + api_token}


def fetch_records(year, month, day):
    """Fetch records released on the given date from the API.

    Returns (records_list, error_flag).
    - On success: (list_of_dicts, False)
    - On failure: ([], True)
    """
    date_str = make_date_string(year, month, day)
    url = API_BASE + "/api/v1/collection/on_this_day?date=" + date_str

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
    except Exception as e:
        # OSError for network failures, ValueError for JSON parse errors
        gc.collect()
        return [], True


def fetch_thumbnail(url):
    """Fetch a JPEG thumbnail from the given URL.

    Returns the raw bytes on success, None on failure.
    """
    try:
        resp = urequests.get(url, headers=_auth_header())
        if resp.status_code == 200:
            data = resp.content
            resp.close()
            return data
        resp.close()
    except Exception:
        pass
    return None


# ============================================================================
# JPEG RENDERING
# ============================================================================

def draw_jpeg(data, x, y, max_w, max_h):
    """Decode and draw a JPEG image, scaled to fit within max_w x max_h
    and centered in the bounding box.

    Uses jpegdec module (standard on Pimoroni firmware).
    Falls back to a placeholder rectangle on failure.
    """
    if data is None:
        _draw_placeholder(x, y, max_w, max_h)
        return

    # Try jpegdec module with smart scaling
    if _HAS_JPEGDEC:
        try:
            jpeg = _jpegdec_lib.JPEG(display)
            try:
                jpeg.open_RAM(memoryview(data))
            except Exception:
                jpeg.open_RAM(data)

            # Attempt smart scaling: get dimensions, pick best scale, center
            try:
                img_h = jpeg.get_height()
                img_w = jpeg.get_width()
                # Try scales from largest to smallest; use first that fits
                # (0=full, 2=half, 4=quarter, 8=eighth)
                for s in (2, 4, 8):
                    if img_w // s <= max_w and img_h // s <= max_h:
                        scale = s
                        break
                else:
                    scale = 0
                sw = img_w // max(1, scale)
                sh = img_h // max(1, scale)
                ox = x + (max_w - sw) // 2
                oy = y + (max_h - sh) // 2
                jpeg.decode(ox, oy, scale)
                return
            except Exception:
                pass

            # Fallback: decode at quarter scale (works for most cover art)
            jpeg.decode(x, y, 4)
            return
        except Exception:
            pass
            return
        except Exception:
            pass

    # Method 2: PicoGraphics built-in JPEG support
    try:
        if hasattr(display, "open_jpeg_from_RAM"):
            display.open_jpeg_from_RAM(data)
            display.decode_jpeg(x, y)
            return
    except Exception:
        pass

    # Method 3: alternate PicoGraphics JPEG API
    try:
        if hasattr(display, "draw_jpeg"):
            display.draw_jpeg(data, x, y)
            return
    except Exception:
        pass

    # All methods failed — draw placeholder
    _draw_placeholder(x, y, max_w, max_h)


def _draw_placeholder(x, y, w, h):
    """Draw a grey placeholder rectangle with a question mark."""
    display.set_pen(_pen_placeholder)
    display.rectangle(x, y, w, h)
    display.set_pen(_pen_dim_text)
    cx = x + w // 2 - display.measure_text("?", scale=2) // 2
    cy = y + h // 2 - 10
    display.text("?", cx, cy, scale=2)


# ============================================================================
# DRAWING: STATUS SCREEN (startup / error)
# ============================================================================

def draw_status(message):
    """Draw a simple centered status message on the display (used during
    startup and for persistent errors)."""
    display.set_pen(_pen_bg)
    display.clear()
    display.set_pen(_pen_status)
    display.set_font("bitmap8")

    lines = message.split("\n")
    line_h = 20
    total_h = len(lines) * line_h
    start_y = (HEIGHT - total_h) // 2

    for i, line in enumerate(lines):
        w = display.measure_text(line, scale=1)
        x = (WIDTH - w) // 2
        display.text(line, x, start_y + i * line_h, scale=1)

    presto.update()


# ============================================================================
# DRAWING: MONTH CALENDAR
# ============================================================================

def draw_month_view():
    """Render the full month calendar view including header, day-of-week
    labels, day grid, and today highlight."""
    display.set_pen(_pen_bg)
    display.clear()

    _draw_month_header()
    _draw_day_labels()
    _draw_day_grid()
    presto.update()


def _draw_month_header():
    """Draw the month/year title and navigation arrows at the top."""
    # Background bar
    display.set_pen(_pen_cell_bg)
    display.rectangle(0, HEADER_Y, WIDTH, HEADER_H)

    # Month and year text (centered)
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    title = "{} {}".format(MONTH_NAMES[view_month - 1], view_year)
    tw = display.measure_text(title, scale=1)
    tx = (WIDTH - tw) // 2
    ty = MONTH_Y
    display.text(title, tx, ty, scale=1)

    # Left arrow
    lx = 12
    ly = HEADER_Y + (HEADER_H - ARROW_H) // 2
    display.set_pen(_pen_cell_bg)  # Match header bg
    display.rectangle(lx, ly, ARROW_W, ARROW_H)
    display.set_pen(_pen_arrow)
    display.set_font("bitmap14_outline")
    display.text("<", lx + 14, ly + 8, scale=1)

    # Right arrow
    rx = WIDTH - ARROW_W - 12
    ry = HEADER_Y + (HEADER_H - ARROW_H) // 2
    display.set_pen(_pen_cell_bg)
    display.rectangle(rx, ry, ARROW_W, ARROW_H)
    display.set_pen(_pen_arrow)
    display.text(">", rx + 12, ry + 8, scale=1)


def _draw_day_labels():
    """Draw Mon..Sun labels below the header."""
    display.set_pen(_pen_dim_text)
    display.set_font("bitmap8")
    for i, name in enumerate(DAY_NAMES):
        cx = GRID_LEFT + i * (CELL_SIZE + CELL_GAP) + CELL_SIZE // 2
        tw = display.measure_text(name, scale=1)
        display.text(name, cx - tw // 2, DOW_Y, scale=1)


def _draw_day_grid():
    """Draw the 7x6 grid of day cells for the current view month."""
    days = days_in_month(view_year, view_month)
    first_dow = day_of_week(view_year, view_month, 1)

    display.set_font("bitmap8")

    # Draw cells for 6 rows
    for row in range(MAX_ROWS):
        for col in range(CELLS_PER_ROW):
            cell_index = row * CELLS_PER_ROW + col
            day_num = cell_index - first_dow + 1

            cx = GRID_LEFT + col * (CELL_SIZE + CELL_GAP)
            cy = CALENDAR_TOP + row * (CELL_SIZE + CELL_GAP)

            if day_num < 1 or day_num > days:
                # Cell belongs to previous/next month — dim it
                display.set_pen(_pen_cell_other)
                display.rectangle(cx, cy, CELL_SIZE, CELL_SIZE)
                if day_num > days:
                    # Show overflow day numbers dimmed
                    overflow = day_num - days
                    display.set_pen(_pen_dim_text)
                    _draw_centered_num(overflow, cx + CELL_SIZE // 2, cy + CELL_SIZE // 2)
                continue

            # Determine cell style
            is_today = (
                view_year == today_year
                and view_month == today_month
                and day_num == today_day
            )
            is_selected = (state == STATE_DAY and day_num == selected_day)

            # Handle today + selected combo specially (show both highlight and border)
            if is_today and is_selected:
                display.set_pen(_pen_today_bg)
                display.rectangle(cx, cy, CELL_SIZE, CELL_SIZE)
                # Selection border on top of today highlight
                display.set_pen(_pen_arrow)
                display.line(cx, cy, cx + CELL_SIZE - 1, cy)
                display.line(cx, cy + CELL_SIZE - 1, cx + CELL_SIZE - 1, cy + CELL_SIZE - 1)
                display.line(cx, cy, cx, cy + CELL_SIZE - 1)
                display.line(cx + CELL_SIZE - 1, cy, cx + CELL_SIZE - 1, cy + CELL_SIZE - 1)
                display.set_pen(_pen_today_text)
                _draw_centered_num(day_num, cx + CELL_SIZE // 2, cy + CELL_SIZE // 2)
                continue

            if is_today:
                display.set_pen(_pen_today_bg)
            elif is_selected:
                # Outline the selected cell (non-today)
                display.set_pen(_pen_cell_bg)
                display.rectangle(cx, cy, CELL_SIZE, CELL_SIZE)
                display.set_pen(_pen_arrow)
                display.line(cx, cy, cx + CELL_SIZE - 1, cy)
                display.line(cx, cy + CELL_SIZE - 1, cx + CELL_SIZE - 1, cy + CELL_SIZE - 1)
                display.line(cx, cy, cx, cy + CELL_SIZE - 1)
                display.line(cx + CELL_SIZE - 1, cy, cx + CELL_SIZE - 1, cy + CELL_SIZE - 1)
                display.set_pen(_pen_normal_text)
                _draw_centered_num(day_num, cx + CELL_SIZE // 2, cy + CELL_SIZE // 2)
                continue
            else:
                display.set_pen(_pen_cell_bg)

            display.rectangle(cx, cy, CELL_SIZE, CELL_SIZE)

            # Day number
            if is_today:
                display.set_pen(_pen_today_text)
            else:
                display.set_pen(_pen_normal_text)
            _draw_centered_num(day_num, cx + CELL_SIZE // 2, cy + CELL_SIZE // 2)


def _draw_centered_num(num, cx, cy):
    """Draw a number centered at (cx, cy)."""
    text = str(num)
    tw = display.measure_text(text, scale=1)
    display.text(text, cx - tw // 2, cy - 5, scale=1)


# ============================================================================
# DRAWING: DAY VIEW (records list)
# ============================================================================

def draw_day_view():
    """Render the day view showing records for the selected date."""
    display.set_pen(_pen_bg)
    display.clear()

    _draw_day_header()

    if records_error:
        _draw_day_error()
        presto.update()
        return

    if not records:
        _draw_day_empty()
        presto.update()
        return

    _draw_record_list()
    presto.update()


def _draw_day_header():
    """Draw the header with formatted date and back button."""
    # Background bar
    display.set_pen(_pen_cell_bg)
    display.rectangle(0, BACK_Y - 4, WIDTH, BACK_H + 8)

    # Back button
    bx, by = BACK_X, BACK_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(bx, by, BACK_W, BACK_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    display.text("< Back", bx + 10, by + 14, scale=1)

    # Formatted date
    date_str = "{} {}, {}".format(
        MONTH_NAMES[view_month - 1], selected_day, view_year
    )
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    tw = display.measure_text(date_str, scale=1)
    display.text(date_str, (WIDTH - tw) // 2, BACK_Y + 8, scale=1)

    # Record count
    count_str = "{} record{}".format(len(records), "s" if len(records) != 1 else "")
    display.set_pen(_pen_dim_text)
    display.set_font("bitmap8")
    cw = display.measure_text(count_str, scale=1)
    # display.text(count_str, WIDTH - cw - 16, BACK_Y + BACK_H - 4, scale=1)
    display.text(count_str, WIDTH - cw - 16, BACK_Y + 14, scale=1)


def _draw_day_error():
    """Show error message when API call failed."""
    display.set_pen(_pen_error)
    display.set_font("bitmap8")
    msg = "Could not reach server"
    mw = display.measure_text(msg, scale=1)
    display.text(msg, (WIDTH - mw) // 2, HEIGHT // 2 - 20, scale=1)

    display.set_pen(_pen_dim_text)
    hint = "Tap < Back to return"
    hw = display.measure_text(hint, scale=1)
    display.text(hint, (WIDTH - hw) // 2, HEIGHT // 2 + 10, scale=1)


def _draw_day_empty():
    """Show message when no records exist for the selected date."""
    display.set_pen(_pen_dim_text)
    display.set_font("bitmap8")
    msg = "No records on this day"
    mw = display.measure_text(msg, scale=1)
    display.text(msg, (WIDTH - mw) // 2, HEIGHT // 2 - 10, scale=1)


def _draw_record_list():
    """Draw the scrollable list of record rows with cover thumbnails.
    Uses dynamic row heights so wrapped text doesn't break layout."""
    start_idx = scroll_offset
    total = len(records)

    # Up arrow if scrolled down
    if scroll_offset > 0:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        display.text("^", WIDTH // 2 - 8, RECORD_START_Y - 28, scale=1)

    # Draw rows with dynamic heights
    cy = RECORD_START_Y
    visible_count = 0
    for i in range(start_idx, total):
        rec = records[i]
        row_bottom = _draw_record_row(rec, cy)
        # Stop if the row would overflow the display
        if row_bottom > HEIGHT - 28:
            break
        cy = row_bottom
        visible_count += 1

    # Down arrow if more records below
    if start_idx + visible_count < total:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        display.text("v", WIDTH // 2 - 8, cy + 4, scale=1)

    # Store how many fit for scroll logic
    global _visible_count
    _visible_count = max(1, visible_count)


def _draw_record_row(rec, y):
    """Draw a single record row. Returns the Y position after the row
    (including separator), so the next row can be positioned correctly
    even when title/artist text wraps to multiple lines."""
    min_h = THUMB_SIZE + 8  # Minimum row height (thumbnail + padding)

    # Fetch and draw thumbnail (top-aligned in row)
    thumb_url = rec.get("mini_cover_url", "")
    thumb_y = y + 4
    if thumb_url:
        jpeg_data = fetch_thumbnail(thumb_url)
        draw_jpeg(jpeg_data, THUMB_MARGIN, thumb_y, THUMB_SIZE, THUMB_SIZE)
        gc.collect()
    else:
        _draw_placeholder(THUMB_MARGIN, thumb_y, THUMB_SIZE, THUMB_SIZE)

    # Title (starts at same height as thumbnail)
    title = rec.get("title", "Unknown Title")
    display.set_font("bitmap8")
    ty = y + 4
    ty = draw_wrapped(title, TEXT_X, ty, TEXT_W, _pen_title, scale=1)

    # Artists
    artists = rec.get("artists", [])
    if artists:
        artist_str = ", ".join(artists)
        ty += 2
        ty = draw_wrapped(artist_str, TEXT_X, ty, TEXT_W, _pen_artist, scale=1)

    # Bottom of content: at least thumbnail bottom, at least min_h
    content_bottom = max(thumb_y + THUMB_SIZE, ty) + 6
    row_bottom = max(y + min_h, content_bottom)

    # Separator line at the computed bottom
    display.set_pen(_pen_cell_other)
    display.line(THUMB_MARGIN, row_bottom - 2, WIDTH - THUMB_MARGIN, row_bottom - 2)

    return row_bottom


# ============================================================================
# TOUCH HANDLING
# ============================================================================
def touch_to_calendar_cell(x, y):
    """Map a touch (x, y) to (row, col) in the calendar grid, or None
    if the touch is outside the grid."""
    if y < CALENDAR_TOP:
        return None

    col = (x - GRID_LEFT) // (CELL_SIZE + CELL_GAP)
    row = (y - CALENDAR_TOP) // (CELL_SIZE + CELL_GAP)

    # Check within cell (not in gap)
    cx = GRID_LEFT + col * (CELL_SIZE + CELL_GAP)
    cy = CALENDAR_TOP + row * (CELL_SIZE + CELL_GAP)
    if cx <= x < cx + CELL_SIZE and cy <= y < cy + CELL_SIZE:
        if 0 <= col < CELLS_PER_ROW and 0 <= row < MAX_ROWS:
            return row, col
    return None


def cell_to_day(row, col):
    """Convert a calendar cell (row, col) to a day number (1-based)
    for the current view month. Returns None if the cell is outside
    the current month."""
    first_dow = day_of_week(view_year, view_month, 1)
    day_num = row * CELLS_PER_ROW + col - first_dow + 1
    days = days_in_month(view_year, view_month)
    if 1 <= day_num <= days:
        return day_num
    return None


def handle_month_touch(x, y):
    """Process a touch event in month view state."""
    global view_year, view_month, selected_day, state, records, records_error, scroll_offset

    # Check left arrow
    lx, ly = 12, HEADER_Y + (HEADER_H - ARROW_H) // 2
    if lx <= x <= lx + ARROW_W and ly <= y <= ly + ARROW_H:
        view_year, view_month = previous_month(view_year, view_month)
        draw_month_view()
        return

    # Check right arrow
    rx, ry = WIDTH - ARROW_W - 12, HEADER_Y + (HEADER_H - ARROW_H) // 2
    if rx <= x <= rx + ARROW_W and ry <= y <= ry + ARROW_H:
        view_year, view_month = next_month(view_year, view_month)
        draw_month_view()
        return

    # Check calendar cells
    cell = touch_to_calendar_cell(x, y)
    if cell is None:
        return

    row, col = cell
    day_num = cell_to_day(row, col)
    if day_num is None:
        return

    # Valid day tapped — fetch records
    selected_day = day_num
    state = STATE_DAY
    scroll_offset = 0
    records_error = False
    records = []

    # Show loading state
    draw_status("Loading records for\n{} {}, {}...".format(
        MONTH_NAMES[view_month - 1], day_num, view_year
    ))

    # Fetch from API
    recs, had_error = fetch_records(view_year, view_month, day_num)
    records = recs
    records_error = had_error

    # Render day view
    draw_day_view()


def handle_day_touch(x, y):
    """Process a tap event in day view state.
    Back button and scroll are handled by drag logic in the main loop."""
    global records, records_error

    # Tap in error state: retry fetching records
    if records_error:
        draw_status("Retrying...")
        recs, had_error = fetch_records(view_year, view_month, selected_day)
        records = recs
        records_error = had_error
        draw_day_view()


# ============================================================================
# MAIN LOOP
# ============================================================================

def init_display():
    """Initialise pens (display is already set up at module level)."""
    try:
        display.set_font("bitmap8")
    except Exception:
        pass
    _init_pens()


def main():
    """Application entry point. Runs the boot sequence then enters the
    main event loop."""
    global state, view_year, view_month, _last_touch
    global selected_day, records, records_error, scroll_offset

    # -- Init display --
    init_display()
    draw_status("Music Library\nStarting up...")
    time.sleep(0.5)

    # -- WiFi --
    if not connect_wifi():
        # Show persistent error; try to reconnect in a loop
        while not connect_wifi():
            time.sleep(10)
            gc.collect()

    # -- NTP sync --
    sync_time()
    set_today()

    # Start at current month and today's day view
    view_year = today_year
    view_month = today_month
    selected_day = today_day
    state = STATE_DAY
    records_error = False

    # Fetch today's records
    draw_status("Loading records for\n{} {}, {}...".format(
        MONTH_NAMES[view_month - 1], today_day, view_year
    ))
    recs, had_error = fetch_records(view_year, view_month, today_day)
    records = recs
    records_error = had_error

    # Enter main loop
    draw_day_view()

    while True:
        touch.poll()

        if not touch.state:
            time.sleep(0.03)
            continue

        x, y = int(touch.x), int(touch.y)
        now = time.ticks_ms()
        if time.ticks_diff(now, _last_touch) < DEBOUNCE_MS:
            continue
        _last_touch = now

        if state == STATE_MONTH:
            handle_month_touch(x, y)
            # Wait for release to avoid re-triggering
            while touch.state:
                touch.poll()
                time.sleep(0.02)

        elif state == STATE_DAY:
            # Check back button immediately (no drag needed)
            if BACK_X <= x <= BACK_X + BACK_W and BACK_Y <= y <= BACK_Y + BACK_H:
                state = STATE_MONTH
                draw_month_view()
                while touch.state:
                    touch.poll()
                    time.sleep(0.02)
                continue

            # Track vertical drag for scrolling
            drag_start_y = y
            dragged = False
            while touch.state:
                touch.poll()
                time.sleep(0.02)
                if touch.state:
                    dy = drag_start_y - int(touch.y)
                    if abs(dy) > 5:
                        dragged = True
                    # Every ~50px of drag = one record scroll
                    if abs(dy) >= 50:
                        total = len(records)
                        if dy > 0:
                            scroll_offset = min(total - _visible_count, scroll_offset + 1)
                        else:
                            scroll_offset = max(0, scroll_offset - 1)
                        draw_day_view()
                        drag_start_y = int(touch.y)

            if not dragged:
                # It was a tap — handle normally
                handle_day_touch(x, y)


# ============================================================================
# STARTUP
# ============================================================================

main()

