"""
Presto Music Library
===================================================
A MicroPython application for the Pimoroni Presto (RP2350B, 720x720 touch
display, WiFi) that connects to the Music Library API and lets you:
- browse records by release date
- search records in the collection

Features:
  - WiFi auto-connect with retry
  - NTP time synchronisation
  - Full text search for collection records 
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
HEADER_H = 31
HEADER_TEXT_H = 14
HEADER_SIDE_MARGIN = 8
HEADER_BUTTON_W = 32
HEADER_BUTTON_H = 25
HEADER_BUTTON_Y = HEADER_Y + (HEADER_H - HEADER_BUTTON_H) // 2
ARROW_W = HEADER_BUTTON_W
ARROW_H = HEADER_BUTTON_H

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
BACK_X = HEADER_SIDE_MARGIN
BACK_Y = HEADER_BUTTON_Y
BACK_W = HEADER_BUTTON_W
BACK_H = HEADER_BUTTON_H
DAY_HEADER_Y = HEADER_Y
DAY_HEADER_H = HEADER_H
DAY_HEADER_TEXT_H = HEADER_TEXT_H
DAY_COUNT_TEXT_H = 8

# Detail view
DETAIL_COVER_SIZE = 150
DETAIL_COVER_X = (WIDTH - DETAIL_COVER_SIZE) // 2
DETAIL_COVER_Y = DAY_HEADER_Y + DAY_HEADER_H + 12
DETAIL_INFO_GAP = 4
DETAIL_TEXT_X = 40
DETAIL_TEXT_W = WIDTH - (2 * DETAIL_TEXT_X)

RECORD_START_Y = DAY_HEADER_Y + DAY_HEADER_H + 8
THUMB_SIZE = 40
THUMB_MARGIN = 8
ROW_PAD_Y = 8
ROW_SEPARATOR_H = 1
TEXT_X = THUMB_MARGIN + THUMB_SIZE + 12
TEXT_W = WIDTH - TEXT_X - 12

# Colors (RGB tuples, converted to pens at runtime)
BG = (24, 24, 27)
CELL_BG = (39, 39, 42)
CELL_OTHER_MONTH = (30, 30, 34)
TODAY_BG = (239, 68, 68)
TODAY_TEXT = (255, 255, 255)
NORMAL_TEXT = (212, 212, 216)
DIM_TEXT = (113, 113, 122)
HEADER_TEXT = (228, 228, 231)
ARROW_COLOR = (161, 161, 170)
BACK_COLOR = (212, 212, 216)
TITLE_COLOR = (228, 228, 231)
ARTIST_COLOR = (161, 161, 170)
ERROR_COLOR = (59, 130, 246)
PLACEHOLDER_BG = (63, 63, 70)
STATUS_TEXT = (161, 161, 170)

# Days of week (Monday first, ISO 8601)
DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
MONTH_NAMES = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
]

# Touch debounce (milliseconds)
DEBOUNCE_MS = 300
DRAG_REDRAW_MS = 40
DRAG_REDRAW_PX = 8
TOUCH_RELEASE_TIMEOUT_MS = 3_000

# WiFi connection timeout (seconds)
WIFI_TIMEOUT = 30

# Display sleep
DISPLAY_SLEEP_MS = 60_000
DISPLAY_BRIGHTNESS = 1.0
DISPLAY_SLEEP_BRIGHTNESS = 0.0
DISPLAY_FADE_MS = 500
DISPLAY_FADE_STEPS = 20

# Home screen
HOME_TITLE = "Music Library"
HOME_TITLE_Y = 60
HOME_BUTTON_W = WIDTH - 80
HOME_BUTTON_H = 50
HOME_BUTTON_X = 40
HOME_BUTTON1_Y = 120
HOME_BUTTON2_Y = HOME_BUTTON1_Y + HOME_BUTTON_H + 10
HOME_BTN_BG = (55, 65, 81)  # Slate blue — distinct from BG and CELL_BG

# On-screen keyboard
KB_MARGIN = 20
KB_KEY_GAP = 3
KB_KEY_H = 38
KB_KEY_W = (WIDTH - 2 * KB_MARGIN - 9 * KB_KEY_GAP) // 10

KB_INPUT_Y = 42
KB_INPUT_H = 28
KB_INPUT_MARGIN = 40
KB_ROWS_START_Y = KB_INPUT_Y + KB_INPUT_H + 12

ALPHA_KEYS = [
    list("qwertyuiop"),
    list("asdfghjkl"),
    list("zxcvbnm"),
]

NUM_KEYS = [
    list("1234567890"),
    list("-/:;()!@#$"),
]

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
STATE_MONTH = 0
STATE_DAY = 1
STATE_RECORD = 2
STATE_HOME = 3
STATE_SEARCH_INPUT = 4
STATE_SEARCH_RESULTS = 5
state = STATE_HOME

# Day view state
selected_day = 0           # 1-based day of month
selected_record_idx = None # Index into records[] for detail view
records = []               # List of record dicts from API
records_error = False      # True if API call failed
# Scroll state
scroll_offset = 0          # Pixel scroll position for day view
_dragging = False          # True while fast scroll redraws are active
_content_height = 0        # Cached total record list height

# Detail view scroll
detail_scroll_offset = 0   # Pixel scroll position for detail view
_detail_content_height = 0 # Cached total detail content height

# Search state
search_query = ""           # Current search buffer (max ~50 chars)
search_results = []         # Records from search API
search_results_error = False
search_scroll_offset = 0    # Separate scroll offset for search results
_search_content_height = 0  # Separate content height cache for search results
keyboard_mode = "alpha"     # "alpha" or "numbers"
previous_state = None       # Track origin for detail-view back navigation

# Touch debounce
_last_touch = 0
_last_drag_redraw = 0

# Display sleep state
_last_activity = 0
_display_awake = True

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
_pen_home_btn = None


def _init_pens():
    """Pre-create all pens from the RGB color constants."""
    global _pen_bg, _pen_cell_bg, _pen_cell_other, _pen_today_bg
    global _pen_today_text, _pen_normal_text, _pen_dim_text, _pen_header_text
    global _pen_arrow, _pen_back, _pen_title, _pen_artist, _pen_error
    global _pen_placeholder, _pen_status, _pen_home_btn

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
    _pen_home_btn = display.create_pen(*HOME_BTN_BG)


# ============================================================================
# HELPER: TEXT WRAPPING
# ============================================================================

def draw_wrapped(text, x, y, max_width, pen, scale=1):
    """Draw text, wrapping at word boundaries to fit within max_width pixels.

    PicoGraphics doesn't support automatic wrapping, so we manually break
    long strings. Returns the Y position after the last line drawn.
    """
    lines = _wrapped_lines(text, max_width, scale=scale)

    line_height = 8 * scale + 4  # bitmap8 is 8px tall, plus spacing
    cy = y
    display.set_pen(pen)
    for line in lines:
        display.text(line, x, cy, scale=scale)
        cy += line_height

    return cy


def display_text(text):
    """Replace characters not available in the bitmap font."""
    replacements = (
        ("–", "-"),
        ("—", "-"),
        ("−", "-"),
        ("‐", "-"),
        ("‑", "-"),
        ("‒", "-"),
        ("“", '"'),
        ("”", '"'),
        ("„", '"'),
        ("«", '"'),
        ("»", '"'),
        ("‘", "'"),
        ("’", "'"),
        ("‚", "'"),
        ("′", "'"),
        ("…", "..."),
        ("•", "*"),
        ("·", "-"),
        ("\u00a0", " "),
        ("\u202f", " "),
        ("\u2009", " "),
        ("\u200a", " "),
        ("\u200b", ""),
    )

    rendered = str(text)
    for original, replacement in replacements:
        rendered = rendered.replace(original, replacement)

    return rendered


def _wrapped_line_count(text, max_width, scale=1):
    """Return how many wrapped lines the text will occupy."""
    return max(1, len(_wrapped_lines(text, max_width, scale=scale)))


def _wrapped_lines(text, max_width, scale=1):
    """Return wrapped lines for text using the display font metrics."""
    words = str(text).split()
    lines = []
    current_line = ""

    if not words:
        return lines

    for word in words:
        test_line = current_line + (" " if current_line else "") + word
        w = display.measure_text(test_line, scale=scale)
        if w <= max_width:
            current_line = test_line
        else:
            if current_line:
                lines.append(current_line)
            if display.measure_text(word, scale=scale) > max_width:
                lines.append(word)
                current_line = ""
            else:
                current_line = word

    if current_line:
        lines.append(current_line)

    return lines


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
# DISPLAY SLEEP
# ============================================================================

def _fade_backlight(start, end, duration_ms=DISPLAY_FADE_MS, steps=DISPLAY_FADE_STEPS):
    """Gradually fade backlight from start to end brightness."""
    step_delay = duration_ms / 1000.0 / steps
    for i in range(steps + 1):
        t = i / steps
        brightness = start + (end - start) * t
        try:
            presto.set_backlight(brightness)
        except Exception:
            return
        time.sleep(step_delay)


def sleep_display():
    """Turn off the display backlight with a gradual fade."""
    global _display_awake
    _fade_backlight(DISPLAY_BRIGHTNESS, DISPLAY_SLEEP_BRIGHTNESS)
    _display_awake = False


def wake_display():
    """Fade the backlight in, then refresh the clock, reconnect WiFi if
    needed, and always return to the home screen."""
    global _display_awake, state
    _fade_backlight(DISPLAY_SLEEP_BRIGHTNESS, DISPLAY_BRIGHTNESS)
    _display_awake = True

    # Refresh today's date from the system clock (may have crossed midnight).
    set_today()

    if not wifi_connected():
        ensure_wifi_connected()

    # Always return to home screen on wake
    state = STATE_HOME
    redraw_current_view()


def wifi_connected():
    """Return True if the WLAN interface is currently connected."""
    try:
        wlan = network.WLAN(network.STA_IF)
        wlan.active(True)
        return wlan.isconnected()
    except Exception:
        return False


def ensure_wifi_connected():
    """Reconnect WiFi if it dropped while the display was asleep."""
    if wifi_connected():
        return True

    return connect_wifi()


def redraw_current_view():
    """Redraw the active view after wake-time status messages."""
    if state == STATE_HOME:
        draw_home_screen()
    elif state == STATE_MONTH:
        draw_month_view()
    elif state == STATE_DAY:
        draw_day_view()
    elif state == STATE_RECORD:
        draw_record_detail()
    elif state == STATE_SEARCH_INPUT:
        draw_search_input()
    elif state == STATE_SEARCH_RESULTS:
        draw_search_results()


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


def set_day_records(recs, had_error):
    """Set day-view records and prepare display caches."""
    global records, records_error, scroll_offset, _content_height

    records = recs
    records_error = had_error
    scroll_offset = 0

    if had_error:
        _content_height = 0
        return

    prepare_records_for_display()


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

def _jpeg_scale_options():
    """Return JPEG scale flags paired with their output-size divisors."""
    full = getattr(_jpegdec_lib, "JPEG_SCALE_FULL", 0)
    half = getattr(_jpegdec_lib, "JPEG_SCALE_HALF", 1)
    quarter = getattr(_jpegdec_lib, "JPEG_SCALE_QUARTER", 2)
    eighth = getattr(_jpegdec_lib, "JPEG_SCALE_EIGHTH", 3)
    return ((full, 1), (half, 2), (quarter, 4), (eighth, 8))


def _close_jpeg(jpeg):
    """Release a jpegdec object if the firmware exposes close()."""
    if jpeg is None:
        return

    try:
        jpeg.close()
    except Exception:
        pass


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
        jpeg = None
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
                # Try scales from largest to smallest; use the first that fits.
                scale = None
                divisor = 1
                for scale_flag, scale_divisor in _jpeg_scale_options():
                    if img_w // scale_divisor <= max_w and img_h // scale_divisor <= max_h:
                        scale = scale_flag
                        divisor = scale_divisor
                        break
                if scale is None:
                    scale, divisor = _jpeg_scale_options()[-1]
                sw = img_w // divisor
                sh = img_h // divisor
                ox = x + (max_w - sw) // 2
                oy = y + (max_h - sh) // 2
                jpeg.decode(ox, oy, scale)
                _close_jpeg(jpeg)
                return
            except Exception:
                pass

            # Fallback: decode at quarter scale (works for most cover art)
            jpeg.decode(x, y, getattr(_jpegdec_lib, "JPEG_SCALE_QUARTER", 2))
            _close_jpeg(jpeg)
            return
        except Exception:
            _close_jpeg(jpeg)
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


HOME_BTN_W = 30
HOME_BTN_H = 25
HOME_BTN_Y = HEADER_Y + (HEADER_H - HOME_BTN_H) // 2


def _draw_month_header():
    """Draw the month/year title, navigation arrows, and Home button."""
    # Background bar
    display.set_pen(_pen_cell_bg)
    display.rectangle(0, HEADER_Y, WIDTH, HEADER_H)

    # Month and year text (centered between arrow buttons)
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    title = "{} {}".format(MONTH_NAMES[view_month - 1], view_year)
    tw = display.measure_text(title, scale=1)
    # Left boundary: after Home + left-arrow; right boundary: before right-arrow
    title_left = HEADER_SIDE_MARGIN + HOME_BTN_W + 4 + ARROW_W
    title_right = WIDTH - ARROW_W - HEADER_SIDE_MARGIN
    title_area = title_right - title_left
    tx = title_left + (title_area - tw) // 2
    ty = HEADER_Y + (HEADER_H - HEADER_TEXT_H) // 2
    display.text(title, tx, ty, scale=1)

    # Home button (leftmost)
    hx = HEADER_SIDE_MARGIN
    hy = HOME_BTN_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(hx, hy, HOME_BTN_W, HOME_BTN_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text("H", hx, hy, HOME_BTN_W, HOME_BTN_H, 8)

    # Left arrow (shifted right to make room for Home)
    lx = hx + HOME_BTN_W + 4
    ly = HEADER_BUTTON_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(lx, ly, ARROW_W, ARROW_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text("<", lx, ly, ARROW_W, ARROW_H, 8)

    # Right arrow
    rx = WIDTH - ARROW_W - HEADER_SIDE_MARGIN
    ry = HEADER_BUTTON_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(rx, ry, ARROW_W, ARROW_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text(">", rx, ry, ARROW_W, ARROW_H, 8)


def _draw_centered_text(text, x, y, w, h, text_h, scale=1):
    """Draw text centered inside a rectangular area."""
    tw = display.measure_text(text, scale=scale)
    tx = x + (w - tw) // 2
    ty = y + (h - text_h) // 2
    display.text(text, tx, ty, scale=scale)


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
# DRAWING: HOME SCREEN (splash)
# ============================================================================

def draw_home_screen():
    """Render the splash screen with two large touch targets."""
    display.set_pen(_pen_bg)
    display.clear()

    # Title
    display.set_pen(_pen_title)
    display.set_font("bitmap14_outline")
    tw = display.measure_text(HOME_TITLE, scale=1)
    display.text(HOME_TITLE, (WIDTH - tw) // 2, HOME_TITLE_Y, scale=1)

    # Buttons
    _draw_home_button(HOME_BUTTON1_Y, "Search Collection")
    _draw_home_button(HOME_BUTTON2_Y, "Today's Records")

    presto.update()


def _draw_home_button(y, label):
    """Draw a large rounded-rectangle button for the splash screen."""
    display.set_pen(_pen_home_btn)
    display.rectangle(HOME_BUTTON_X, y, HOME_BUTTON_W, HOME_BUTTON_H)
    display.set_pen(_pen_today_text)
    display.set_font("bitmap8")
    tw = display.measure_text(label, scale=1)
    tx = HOME_BUTTON_X + (HOME_BUTTON_W - tw) // 2
    ty = y + (HOME_BUTTON_H - 8) // 2
    display.text(label, tx, ty, scale=1)


# ============================================================================
# DRAWING: SEARCH INPUT (keyboard)
# ============================================================================

def draw_search_input():
    """Render the search input view with query field and on-screen keyboard."""
    display.set_pen(_pen_bg)
    display.clear()

    _draw_search_input_header()

    # Query text field
    display.set_pen(_pen_cell_bg)
    display.rectangle(KB_INPUT_MARGIN, KB_INPUT_Y,
                      WIDTH - 2 * KB_INPUT_MARGIN, KB_INPUT_H)
    display.set_pen(_pen_header_text)
    display.set_font("bitmap8")
    # Show cursor as underscore if query is empty
    display_q = search_query if search_query else "_"
    display.text(display_q, KB_INPUT_MARGIN + 8, KB_INPUT_Y + 12, scale=1)

    _draw_keyboard()
    presto.update()


def _draw_search_input_header():
    """Draw the search input header with title and Back-to-Home button."""
    display.set_pen(_pen_cell_bg)
    display.rectangle(0, DAY_HEADER_Y, WIDTH, DAY_HEADER_H)

    # Back-to-Home button
    bx, by = BACK_X, BACK_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(bx, by, BACK_W, BACK_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text("<", bx, by, BACK_W, BACK_H, DAY_COUNT_TEXT_H)

    # Title
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    title = "Search"
    tw = display.measure_text(title, scale=1)
    display.text(title, (WIDTH - tw) // 2,
                 DAY_HEADER_Y + (DAY_HEADER_H - DAY_HEADER_TEXT_H) // 2, scale=1)


def _draw_keyboard():
    """Draw the on-screen QWERTY or numbers keyboard."""
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
    ok_pen = _pen_dim_text if search_query.strip() == "" else _pen_header_text
    _draw_key(bx, cy, "OK", bottom_w, KB_KEY_H, text_pen=ok_pen)


def _draw_key(x, y, label, w, h, text_pen=None):
    """Draw a single keyboard key as a rounded rectangle with centered label."""
    display.set_pen(_pen_cell_bg)
    display.rectangle(x, y, w, h)
    pen = text_pen if text_pen is not None else _pen_normal_text
    display.set_pen(pen)
    tw = display.measure_text(label, scale=1)
    tx = x + (w - tw) // 2
    ty = y + (h - 8) // 2
    display.text(label, tx, ty, scale=1)


def _keyboard_hit_test(x, y):
    """Map a touch (x, y) to a keyboard action.

    Returns: a character string, "toggle", "space", "backspace", "ok", or None.
    """
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


def _flash_key(kx, ky, kw, kh, label):
    """Brief visual feedback for a key press."""
    _draw_key(kx, ky, label, kw, kh, text_pen=_pen_today_text)
    display.set_pen(_pen_arrow)
    display.rectangle(kx, ky, kw, kh)
    presto.update()
    time.sleep(0.05)


# ============================================================================
# DRAWING: SEARCH RESULTS
# ============================================================================

def draw_search_results():
    """Render the search results view, reusing record-list rendering."""
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
    """Draw the search results header with Back button and query label."""
    display.set_pen(_pen_cell_bg)
    display.rectangle(0, DAY_HEADER_Y, WIDTH, DAY_HEADER_H)

    # Back button → search input (preserves query)
    bx, by = BACK_X, BACK_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(bx, by, BACK_W, BACK_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text("<", bx, by, BACK_W, BACK_H, DAY_COUNT_TEXT_H)

    # Title "Search: <query>" — truncate for display only, never mutate
    # the global search_query so user can refine on Back
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    display_label = "Search: " + search_query
    max_w = WIDTH - (BACK_X + BACK_W + 8) - 8
    if display.measure_text(display_label, scale=1) > max_w:
        suffix = "..."
        display_q = search_query
        while (display.measure_text("Search: " + display_q + suffix, scale=1) > max_w
               and len(display_q) > 0):
            display_q = display_q[:-1]
        display_label = "Search: " + (display_q + suffix if display_q else suffix)
    tw = display.measure_text(display_label, scale=1)
    display.text(display_label, (WIDTH - tw) // 2,
                 DAY_HEADER_Y + (DAY_HEADER_H - DAY_HEADER_TEXT_H) // 2, scale=1)


def _draw_search_record_list():
    """Draw the scrollable search results list, mirroring day-view scroll."""
    global search_scroll_offset

    max_offset = _search_max_scroll_offset()
    search_scroll_offset = min(max(0, search_scroll_offset), max_offset)

    # Up arrow if scrolled down
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

    # Down arrow if more records below
    if search_scroll_offset < max_offset:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        display.text("v", WIDTH // 2 - 8, HEIGHT - 24, scale=1)


def _search_max_scroll_offset():
    """Return the maximum pixel scroll offset for search results."""
    viewport_h = HEIGHT - RECORD_START_Y - 28
    return max(0, _search_content_height - viewport_h)


def _draw_search_empty():
    """Show 'No records found' message."""
    display.set_pen(_pen_dim_text)
    display.set_font("bitmap8")
    msg = "No records found"
    mw = display.measure_text(msg, scale=1)
    display.text(msg, (WIDTH - mw) // 2, HEIGHT // 2 - 10, scale=1)


def _draw_search_error():
    """Show search error message with retry hint."""
    display.set_pen(_pen_error)
    display.set_font("bitmap8")
    msg = "Could not reach server"
    mw = display.measure_text(msg, scale=1)
    display.text(msg, (WIDTH - mw) // 2, HEIGHT // 2 - 20, scale=1)

    display.set_pen(_pen_dim_text)
    hint = "Tap to retry"
    hw = display.measure_text(hint, scale=1)
    display.text(hint, (WIDTH - hw) // 2, HEIGHT // 2 + 10, scale=1)


# ============================================================================
# DRAWING: DAY VIEW (records list)
# ============================================================================

def draw_day_view():
    """Render the day view showing records for the selected date."""
    display.set_pen(_pen_bg)
    display.clear()

    if records_error:
        _draw_day_error()
        _draw_day_header()
        presto.update()
        return

    if not records:
        _draw_day_empty()
        _draw_day_header()
        presto.update()
        return

    _draw_record_list()
    _draw_day_header()
    presto.update()


def _draw_day_header():
    """Draw the header with formatted date and back button."""
    # Background bar
    display.set_pen(_pen_cell_bg)
    display.rectangle(0, DAY_HEADER_Y, WIDTH, DAY_HEADER_H)

    # Back button
    bx, by = BACK_X, BACK_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(bx, by, BACK_W, BACK_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text("<", bx, by, BACK_W, BACK_H, DAY_COUNT_TEXT_H)

    # Formatted date
    date_str = "{} {}, {}".format(
        MONTH_NAMES[view_month - 1], selected_day, view_year
    )
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    tw = display.measure_text(date_str, scale=1)
    display.text(
        date_str,
        (WIDTH - tw) // 2,
        DAY_HEADER_Y + (DAY_HEADER_H - DAY_HEADER_TEXT_H) // 2,
        scale=1
    )

    # Record count
    count_str = "{} record{}".format(len(records), "s" if len(records) != 1 else "")
    display.set_pen(_pen_dim_text)
    display.set_font("bitmap8")
    cw = display.measure_text(count_str, scale=1)
    display.text(
        count_str,
        WIDTH - cw - 11,
        DAY_HEADER_Y + (DAY_HEADER_H - DAY_COUNT_TEXT_H) // 2,
        scale=1
    )


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
    global scroll_offset

    max_offset = _max_scroll_offset()
    scroll_offset = min(max(0, scroll_offset), max_offset)

    # Up arrow if scrolled down
    if scroll_offset > 0:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        display.text("^", WIDTH // 2 - 8, RECORD_START_Y - 28, scale=1)

    cy = RECORD_START_Y - scroll_offset

    for rec in records:
        row_h = rec.get("_row_height", THUMB_SIZE + 8)
        row_bottom = cy + row_h

        if row_bottom <= RECORD_START_Y:
            cy = row_bottom
            continue

        if cy >= HEIGHT - 28:
            break

        _draw_record_row(rec, cy)
        cy = row_bottom

    # Down arrow if more records below
    if scroll_offset < max_offset:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        display.text("v", WIDTH // 2 - 8, HEIGHT - 24, scale=1)

def _max_scroll_offset():
    """Return the maximum pixel scroll offset for the current records."""
    viewport_h = HEIGHT - RECORD_START_Y - 28
    return max(0, _content_height - viewport_h)


def prepare_records_for_display(recs=None):
    """Cache display fields, row heights, and thumbnails for a record list.

    If recs is None, uses the global records list (day view).
    When recs is search_results, updates _search_content_height.
    """
    global _content_height, _search_content_height, records, search_results
    if recs is None:
        recs = records

    display.set_font("bitmap8")

    is_search = recs is search_results
    if is_search:
        _search_content_height = 0
    else:
        _content_height = 0

    for rec in recs:
        _prepare_record_for_display(rec)
        if is_search:
            _search_content_height += rec.get("_row_height", THUMB_SIZE + 8)
        else:
            _content_height += rec.get("_row_height", THUMB_SIZE + 8)

    preload_record_thumbnails(recs)
    gc.collect()


def _prepare_record_for_display(rec):
    """Prepare one record's display text and row height."""
    title = display_text(rec.get("title", "Unknown Title"))
    artists = rec.get("artists", [])
    artist_str = display_text(", ".join(artists)) if artists else ""
    meta_text = _record_meta_text(rec)

    rec["_display_title"] = title
    rec["_display_artists"] = artist_str
    rec["_display_meta"] = meta_text
    rec["_thumb_url"] = _record_thumbnail_url(rec)
    rec["_row_height"] = _record_row_height(rec)


def preload_record_thumbnails(recs=None):
    """Fetch thumbnail bytes before the first draw of a record list."""
    if recs is None:
        recs = records
    for rec in recs:
        if rec.get("micro_cover_url", ""):
            _record_thumbnail_data(rec)


def _record_row_height(rec):
    """Calculate a record row height without drawing it."""
    min_h = THUMB_SIZE + ROW_PAD_Y * 2 + ROW_SEPARATOR_H
    title = rec.get("_display_title", display_text(rec.get("title", "Unknown Title")))
    ty = _wrapped_line_count(title, TEXT_W, scale=1) * 12

    artist_str = rec.get("_display_artists", "")
    if artist_str:
        ty += 2 + _wrapped_line_count(artist_str, TEXT_W, scale=1) * 12

    if rec.get("_display_meta", _record_meta_text(rec)):
        ty += 2 + 12

    content_h = max(THUMB_SIZE, ty) + ROW_PAD_Y * 2 + ROW_SEPARATOR_H
    return max(min_h, content_h)


def _record_meta_text(rec):
    """Return compact format/date metadata for a record row."""
    record_format = rec.get("format", "")
    release_year = _release_year(rec.get("release_date", ""))

    if record_format and release_year:
        return "{} | {}".format(record_format, release_year)
    if record_format:
        return record_format
    return release_year


def _release_year(release_date):
    """Extract a display year from an API release_date value."""
    if not release_date:
        return ""
    return str(release_date)[:4]


def _record_thumbnail_data(rec):
    """Fetch thumbnail bytes once per record and reuse them on redraw."""
    if rec.get("_thumb_failed", False):
        return None

    cached = rec.get("_thumb_data", None)
    if cached is not None:
        return cached

    thumb_url = rec.get("_thumb_url", "") or _record_thumbnail_url(rec)
    if not thumb_url:
        return None

    data = fetch_thumbnail(thumb_url)
    if data is None:
        rec["_thumb_failed"] = True
    else:
        rec["_thumb_data"] = data

    return data


def _record_thumbnail_url(rec):
    """Return the preferred cover URL for a record row."""
    return (
        rec.get("micro_cover_url", "")
        or rec.get("mini_cover_url", "")
        or rec.get("thumb_url", "")
    )


def _draw_record_row(rec, y):
    """Draw a single record row using its cached layout height."""
    row_h = rec.get("_row_height", None)
    if row_h is None:
        row_h = _record_row_height(rec)
    row_bottom = y + row_h

    # Fetch and draw thumbnail (top-aligned in row)
    thumb_y = y + ROW_PAD_Y
    if _dragging:
        _draw_placeholder(THUMB_MARGIN, thumb_y, THUMB_SIZE, THUMB_SIZE)
    else:
        jpeg_data = _record_thumbnail_data(rec)
        if jpeg_data is not None:
            draw_jpeg(jpeg_data, THUMB_MARGIN, thumb_y, THUMB_SIZE, THUMB_SIZE)
        else:
            _draw_placeholder(THUMB_MARGIN, thumb_y, THUMB_SIZE, THUMB_SIZE)

    # Title (starts at same height as thumbnail)
    title = rec.get("_display_title", display_text(rec.get("title", "Unknown Title")))
    display.set_font("bitmap8")
    ty = y + ROW_PAD_Y
    ty = draw_wrapped(title, TEXT_X, ty, TEXT_W, _pen_title, scale=1)

    # Artists
    artist_str = rec.get("_display_artists", "")
    if artist_str:
        ty += 2
        ty = draw_wrapped(artist_str, TEXT_X, ty, TEXT_W, _pen_artist, scale=1)

    meta_text = rec.get("_display_meta", _record_meta_text(rec))
    if meta_text:
        ty += 2
        ty = draw_wrapped(meta_text, TEXT_X, ty, TEXT_W, _pen_dim_text, scale=1)

    # Separator line at the computed bottom
    display.set_pen(_pen_cell_other)
    display.line(
        THUMB_MARGIN,
        row_bottom - ROW_SEPARATOR_H,
        WIDTH - THUMB_MARGIN,
        row_bottom - ROW_SEPARATOR_H
    )


# ============================================================================
# DRAWING: RECORD DETAIL
# ============================================================================

def _max_detail_scroll_offset():
    """Return the maximum pixel scroll offset for the detail view."""
    if _detail_content_height == 0:
        return 0
    content_bottom = DETAIL_COVER_Y + _detail_content_height
    return max(0, content_bottom - HEIGHT)


def _measure_detail_text_height(text, font="bitmap8", scale=1, max_w=None):
    """Return the pixel height that text would occupy when drawn wrapped."""
    if max_w is None:
        max_w = DETAIL_TEXT_W
    lines = _wrapped_lines(text, max_w, scale=scale)
    line_height = 8 * scale + 4
    return len(lines) * line_height


def _measure_detail_content(rec):
    """Compute and cache the total height of the scrollable detail content."""
    global _detail_content_height

    h = 0

    # Title (above cover)
    title = rec.get("_display_title",
                    display_text(rec.get("title", "Unknown Title")))
    h += _measure_detail_text_height(title, font="bitmap14_outline", scale=1)
    h += 6

    # Artists (above cover)
    artist_str = rec.get("_display_artists", "")
    if not artist_str:
        artists = rec.get("artists", [])
        artist_str = display_text(", ".join(artists)) if artists else ""
    if artist_str:
        h += _measure_detail_text_height(artist_str)
        h += 4

    h += DETAIL_INFO_GAP  # gap before cover

    # Cover
    h += DETAIL_COVER_SIZE
    h += DETAIL_INFO_GAP

    # Genres (below cover)
    genres = rec.get("genres", [])
    if genres:
        genre_str = display_text(", ".join(genres))
        h += _measure_detail_text_height(genre_str)
        h += 4

    h += 6

    # Metadata line: record_type | format | year
    meta_parts = []
    record_type = rec.get("record_type", "")
    if record_type:
        meta_parts.append(display_text(record_type))
    record_format = rec.get("format", "")
    if record_format:
        meta_parts.append(display_text(record_format))
    release_date = rec.get("release_date", "")
    if release_date:
        meta_parts.append(str(release_date)[:4])

    if meta_parts:
        meta_str = " | ".join(meta_parts)
        h += _measure_detail_text_height(meta_str)
        h += 4

    # Purchased at
    purchased_at = rec.get("purchased_at", "")
    if purchased_at:
        purch_str = "Purchased: " + display_text(str(purchased_at)[:10])
        h += _measure_detail_text_height(purch_str)

    _detail_content_height = h


def _set_clip_below_header():
    """Restrict drawing to the area below the fixed header."""
    try:
        display.set_clip(0, DAY_HEADER_Y + DAY_HEADER_H,
                         WIDTH, HEIGHT - (DAY_HEADER_Y + DAY_HEADER_H))
    except Exception:
        pass


def _remove_clip():
    """Remove any active clip rectangle."""
    try:
        display.remove_clip()
    except Exception:
        pass


def draw_record_detail():
    """Render the individual record detail view. Layout order:
    title, artists, large cover, genres, metadata, purchased at."""
    global detail_scroll_offset

    display.set_pen(_pen_bg)
    display.clear()

    if previous_state == STATE_SEARCH_RESULTS:
        rec = search_results[selected_record_idx]
    else:
        rec = records[selected_record_idx]

    # Measure content height so scroll bounds are known
    _measure_detail_content(rec)

    # Clamp scroll offset
    max_off = _max_detail_scroll_offset()
    if detail_scroll_offset > max_off:
        detail_scroll_offset = max_off
    if detail_scroll_offset < 0:
        detail_scroll_offset = 0

    offset = detail_scroll_offset

    _draw_detail_header()

    # Clip scrolling content below the header
    _set_clip_below_header()

    # Start drawing below the header
    y = DETAIL_COVER_Y - offset

    # Title and artists (above cover)
    y = _draw_detail_title_artists(rec, y)
    y += DETAIL_INFO_GAP  # gap before cover

    # Cover image
    _draw_detail_cover(rec, y)

    # Genres, metadata, purchased at (below cover)
    y = y + DETAIL_COVER_SIZE + DETAIL_INFO_GAP
    _draw_detail_info_below_cover(rec, y)

    # Scroll indicators
    display.set_font("bitmap14_outline")
    if offset > 0:
        display.set_pen(_pen_arrow)
        display.text("^", WIDTH // 2 - 8, DAY_HEADER_H + 4, scale=1)
    if offset < max_off:
        display.set_pen(_pen_arrow)
        display.text("v", WIDTH // 2 - 8, HEIGHT - 24, scale=1)

    _remove_clip()

    presto.update()


def _draw_detail_header():
    """Draw the record detail header with back button."""
    display.set_pen(_pen_cell_bg)
    display.rectangle(0, DAY_HEADER_Y, WIDTH, DAY_HEADER_H)

    # Back button
    bx, by = BACK_X, BACK_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(bx, by, BACK_W, BACK_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text("<", bx, by, BACK_W, BACK_H, DAY_COUNT_TEXT_H)

    # Title label
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    label = "Record"
    tw = display.measure_text(label, scale=1)
    display.text(
        label,
        (WIDTH - tw) // 2,
        DAY_HEADER_Y + (DAY_HEADER_H - DAY_HEADER_TEXT_H) // 2,
        scale=1
    )


def _draw_detail_title_artists(rec, y):
    """Draw title and artists above the cover. Returns y after drawing."""
    # Title
    title = rec.get("_display_title",
                    display_text(rec.get("title", "Unknown Title")))
    y = _draw_detail_text_line(title, y, _pen_title,
                               font="bitmap14_outline", scale=1)
    y += 6

    # Artists
    artist_str = rec.get("_display_artists", "")
    if not artist_str:
        artists = rec.get("artists", [])
        artist_str = display_text(", ".join(artists)) if artists else ""
    if artist_str:
        y = _draw_detail_text_line(artist_str, y, _pen_artist)
        y += 4

    return y


def _draw_detail_cover(rec, y):
    """Fetch and draw the cover art at the given y position."""
    # Skip if entirely outside viewport
    if y + DETAIL_COVER_SIZE <= DAY_HEADER_Y + DAY_HEADER_H:
        return
    if y >= HEIGHT:
        return

    thumb_url = (
        rec.get("thumb_url", "")
        or rec.get("mini_cover_url", "")
        or rec.get("micro_cover_url", "")
    )

    if not thumb_url:
        _draw_placeholder(DETAIL_COVER_X, y,
                          DETAIL_COVER_SIZE, DETAIL_COVER_SIZE)
        return

    # Use cached data or fetch
    data = rec.get("_detail_thumb_data", None)
    if data is None and not rec.get("_detail_thumb_failed", False):
        data = fetch_thumbnail(thumb_url)
        if data is None:
            rec["_detail_thumb_failed"] = True
        else:
            rec["_detail_thumb_data"] = data

    if data is not None:
        draw_jpeg(data, DETAIL_COVER_X, y,
                  DETAIL_COVER_SIZE, DETAIL_COVER_SIZE)
    else:
        _draw_placeholder(DETAIL_COVER_X, y,
                          DETAIL_COVER_SIZE, DETAIL_COVER_SIZE)


def _draw_detail_info_below_cover(rec, y):
    """Draw genres, metadata line, and purchased-at below the cover."""
    # Genres
    genres = rec.get("genres", [])
    if genres:
        genre_str = display_text(", ".join(genres))
        y = _draw_detail_text_line(genre_str, y, _pen_dim_text)
        y += 4

    y += 6

    # Metadata: record_type | format | year
    meta_parts = []
    record_type = rec.get("record_type", "")
    if record_type:
        meta_parts.append(display_text(record_type))
    record_format = rec.get("format", "")
    if record_format:
        meta_parts.append(display_text(record_format))
    release_date = rec.get("release_date", "")
    if release_date:
        meta_parts.append(str(release_date)[:4])

    if meta_parts:
        meta_str = " | ".join(meta_parts)
        y = _draw_detail_text_line(meta_str, y, _pen_dim_text)
        y += 4

    # Purchased at
    purchased_at = rec.get("purchased_at", "")
    if purchased_at:
        purch_str = "Purchased: " + display_text(str(purchased_at)[:10])
        y = _draw_detail_text_line(purch_str, y, _pen_dim_text)

    return y


def _draw_detail_text_line(text, y, pen, font="bitmap8", scale=1):
    """Draw text centered horizontally at y, wrapping if needed.
    Returns the y-position after drawing (including wrapped lines)."""
    max_w = DETAIL_TEXT_W
    display.set_pen(pen)
    display.set_font(font)

    lines = _wrapped_lines(text, max_w, scale=scale)
    line_height = 8 * scale + 4
    cy = y
    for line in lines:
        tw = display.measure_text(line, scale=scale)
        display.text(line, (WIDTH - tw) // 2, cy, scale=scale)
        cy += line_height

    return cy


# ============================================================================
# TOUCH HANDLING
# ============================================================================
def read_touch():
    """Return the current touch as (x, y), or None when not pressed."""
    try:
        touch.poll()
    except Exception:
        pass

    try:
        if touch.state:
            return int(touch.x), int(touch.y)
    except Exception:
        pass

    for method_name in ("read", "get_touch"):
        method = getattr(touch, method_name, None)
        if method is None:
            continue

        try:
            point = method()
        except Exception:
            continue

        normalised = _normalise_touch(point)
        if normalised is not None:
            return normalised

    return None


def _normalise_touch(point):
    """Convert common touch return shapes to (x, y)."""
    if not point:
        return None

    if isinstance(point, (tuple, list)):
        if len(point) == 2:
            return int(point[0]), int(point[1])
        if len(point) >= 3 and point[0] is not None:
            return int(point[1]), int(point[2])
        return None

    try:
        if hasattr(point, "state") and not point.state:
            return None
        return int(point.x), int(point.y)
    except Exception:
        return None


def wait_for_touch_release():
    """Block until the active touch is released."""
    start = time.ticks_ms()
    while read_touch() is not None:
        if time.ticks_diff(time.ticks_ms(), start) >= TOUCH_RELEASE_TIMEOUT_MS:
            return False
        time.sleep(0.02)
    return True


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


def touch_to_record_index(y, recs=None, offset=None):
    """Map a touch y-coordinate to a record list index, accounting for
    scroll offset. Use recs/offset params for search results, or defaults
    for day view."""
    if recs is None:
        recs = records
        if offset is None:
            offset = scroll_offset
    elif offset is None:
        offset = search_scroll_offset

    if not recs:
        return None

    cy = RECORD_START_Y - offset
    for i, rec in enumerate(recs):
        row_h = rec.get("_row_height", THUMB_SIZE + 8)
        if cy <= y < cy + row_h:
            return i
        cy += row_h
    return None


def handle_home_touch(x, y):
    """Process a touch event on the home/splash screen."""
    global state, search_query, keyboard_mode
    global view_year, view_month, selected_day

    # "Search Collection" button
    if (HOME_BUTTON_X <= x <= HOME_BUTTON_X + HOME_BUTTON_W and
            HOME_BUTTON1_Y <= y <= HOME_BUTTON1_Y + HOME_BUTTON_H):
        search_query = ""
        keyboard_mode = "alpha"
        state = STATE_SEARCH_INPUT
        draw_search_input()
        return

    # "Today's Records" button → month view with today highlighted
    if (HOME_BUTTON_X <= x <= HOME_BUTTON_X + HOME_BUTTON_W and
            HOME_BUTTON2_Y <= y <= HOME_BUTTON2_Y + HOME_BUTTON_H):
        view_year = today_year
        view_month = today_month
        selected_day = today_day
        state = STATE_MONTH
        draw_month_view()
        return


def handle_search_input_touch(x, y):
    """Process a touch event in search input view."""
    global search_query, keyboard_mode, state, search_results, search_results_error
    global search_scroll_offset, _search_content_height, previous_state

    # Header Back → Home
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


def handle_search_results_touch(x, y):
    """Process a tap event in search results view.
    Back button, error retry, and record row taps.
    Row scroll is handled by the drag logic in the main loop."""
    global state, search_results, search_results_error
    global search_scroll_offset, selected_record_idx, detail_scroll_offset
    global previous_state, records

    # Back button → search input (preserves search_query so user can refine)
    if BACK_X <= x <= BACK_X + BACK_W and BACK_Y <= y <= BACK_Y + BACK_H:
        state = STATE_SEARCH_INPUT
        draw_search_input()
        return

    # Error state: retry on tap anywhere
    if search_results_error:
        draw_status("Retrying search...")
        if not ensure_wifi_connected():
            search_results = []
            draw_search_results()
            return
        recs, had_error = fetch_search_results(search_query)
        search_results = recs
        search_results_error = had_error
        search_scroll_offset = 0
        if not had_error and recs:
            prepare_records_for_display(recs)
        draw_search_results()
        return

    # Record row tap → detail view
    if not search_results_error and search_results:
        rec_idx = touch_to_record_index(y, recs=search_results,
                                         offset=search_scroll_offset)

        if rec_idx is not None:
            selected_record_idx = rec_idx
            detail_scroll_offset = 0
            previous_state = STATE_SEARCH_RESULTS
            state = STATE_RECORD
            draw_record_detail()


def handle_month_touch(x, y):
    """Process a touch event in month view state."""
    global view_year, view_month, selected_day, state, records, records_error, scroll_offset

    # Check Home button
    hx, hy = HEADER_SIDE_MARGIN, HOME_BTN_Y
    if hx <= x <= hx + HOME_BTN_W and hy <= y <= hy + HOME_BTN_H:
        state = STATE_HOME
        draw_home_screen()
        return

    # Check left arrow (shifted right to make room for Home)
    lx = HEADER_SIDE_MARGIN + HOME_BTN_W + 4
    ly = HEADER_BUTTON_Y
    if lx <= x <= lx + ARROW_W and ly <= y <= ly + ARROW_H:
        view_year, view_month = previous_month(view_year, view_month)
        draw_month_view()
        return

    # Check right arrow
    rx, ry = WIDTH - ARROW_W - HEADER_SIDE_MARGIN, HEADER_BUTTON_Y
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
    set_day_records(recs, had_error)

    # Render day view
    draw_day_view()


def handle_day_touch(x, y):
    """Process a tap event in day view state.
    Back button and scroll are handled by drag logic in the main loop."""
    global records, records_error

    # Tap in error state: retry fetching records
    if records_error:
        draw_status("Retrying...")
        if not ensure_wifi_connected():
            set_day_records([], True)
            draw_day_view()
            return

        recs, had_error = fetch_records(view_year, view_month, selected_day)
        set_day_records(recs, had_error)
        draw_day_view()
        return

    # Row taps are handled by the main loop before this function is called.


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
    global selected_day, selected_record_idx, records, records_error
    global scroll_offset, detail_scroll_offset
    global _dragging, previous_state
    global _last_activity, _last_drag_redraw
    global search_scroll_offset

    # -- Init display --
    init_display()
    try:
        presto.set_backlight(DISPLAY_BRIGHTNESS)
    except Exception:
        pass
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

    # Start on splash screen — no auto-fetch
    view_year = today_year
    view_month = today_month
    selected_day = today_day
    state = STATE_HOME
    records_error = False
    scroll_offset = 0

    draw_home_screen()
    _last_activity = time.ticks_ms()

    while True:
        touch_point = read_touch()
        now = time.ticks_ms()

        if _display_awake and time.ticks_diff(now, _last_activity) >= DISPLAY_SLEEP_MS:
            sleep_display()

        if touch_point is None:
            time.sleep(0.03)
            continue

        if not _display_awake:
            wake_display()
            _last_activity = now
            _last_touch = now
            wait_for_touch_release()
            continue

        x, y = touch_point
        if time.ticks_diff(now, _last_touch) < DEBOUNCE_MS:
            time.sleep(0.02)
            continue
        _last_touch = now
        _last_activity = now

        # -- STATE_HOME: splash screen --
        if state == STATE_HOME:
            handle_home_touch(x, y)
            wait_for_touch_release()

        # -- STATE_SEARCH_INPUT: on-screen keyboard --
        elif state == STATE_SEARCH_INPUT:
            handle_search_input_touch(x, y)
            wait_for_touch_release()

        # -- STATE_SEARCH_RESULTS: search results list --
        elif state == STATE_SEARCH_RESULTS:
            # Check back button immediately (no drag needed)
            if BACK_X <= x <= BACK_X + BACK_W and BACK_Y <= y <= BACK_Y + BACK_H:
                state = STATE_SEARCH_INPUT
                draw_search_input()
                wait_for_touch_release()
                continue

            # Error state: retry on tap anywhere (before drag)
            if search_results_error:
                handle_search_results_touch(x, y)
                wait_for_touch_release()
                continue

            # Track vertical drag for scrolling
            drag_start_y = y
            last_drag_y = y
            pending_delta = 0
            dragged = False
            _dragging = False
            _last_drag_redraw = time.ticks_ms()
            while True:
                touch_point = read_touch()
                if touch_point is None:
                    break

                current_y = touch_point[1]
                if abs(current_y - drag_start_y) >= DRAG_REDRAW_PX:
                    dragged = True

                pending_delta += last_drag_y - current_y
                now = time.ticks_ms()
                redraw_due = time.ticks_diff(now, _last_drag_redraw) >= DRAG_REDRAW_MS
                if abs(pending_delta) >= DRAG_REDRAW_PX and redraw_due:
                    max_offset = _search_max_scroll_offset()
                    new_offset = min(max(0, search_scroll_offset + pending_delta), max_offset)
                    if new_offset != search_scroll_offset:
                        search_scroll_offset = new_offset
                        _dragging = True
                        draw_search_results()
                        _last_drag_redraw = now
                    pending_delta = 0

                last_drag_y = current_y
                time.sleep(0.01)

            if dragged and pending_delta:
                max_offset = _search_max_scroll_offset()
                new_offset = min(max(0, search_scroll_offset + pending_delta), max_offset)
                if new_offset != search_scroll_offset:
                    search_scroll_offset = new_offset
                    _dragging = True

            if _dragging:
                _dragging = False
                draw_search_results()

            if not dragged:
                # Record row tap handled by handle_search_results_touch
                handle_search_results_touch(x, y)

        elif state == STATE_MONTH:
            handle_month_touch(x, y)
            wait_for_touch_release()

        elif state == STATE_DAY:
            # Check back button immediately (no drag needed)
            if BACK_X <= x <= BACK_X + BACK_W and BACK_Y <= y <= BACK_Y + BACK_H:
                state = STATE_MONTH
                draw_month_view()
                wait_for_touch_release()
                continue

            # Track vertical drag for scrolling
            drag_start_y = y
            last_drag_y = y
            pending_delta = 0
            dragged = False
            _dragging = False
            _last_drag_redraw = time.ticks_ms()
            while True:
                touch_point = read_touch()
                if touch_point is None:
                    break

                current_y = touch_point[1]
                if abs(current_y - drag_start_y) >= DRAG_REDRAW_PX:
                    dragged = True

                pending_delta += last_drag_y - current_y
                now = time.ticks_ms()
                redraw_due = time.ticks_diff(now, _last_drag_redraw) >= DRAG_REDRAW_MS
                if abs(pending_delta) >= DRAG_REDRAW_PX and redraw_due:
                    max_offset = _max_scroll_offset()
                    new_offset = min(max(0, scroll_offset + pending_delta), max_offset)
                    if new_offset != scroll_offset:
                        scroll_offset = new_offset
                        _dragging = True
                        draw_day_view()
                        _last_drag_redraw = now
                    pending_delta = 0

                last_drag_y = current_y
                time.sleep(0.01)

            if dragged and pending_delta:
                max_offset = _max_scroll_offset()
                new_offset = min(max(0, scroll_offset + pending_delta), max_offset)
                if new_offset != scroll_offset:
                    scroll_offset = new_offset
                    _dragging = True

            if _dragging:
                _dragging = False
                draw_day_view()

            if not dragged:
                # Check for record row tap -> detail view
                if not records_error and records:
                    rec_idx = touch_to_record_index(y)
                    if rec_idx is not None:
                        selected_record_idx = rec_idx
                        detail_scroll_offset = 0
                        previous_state = STATE_DAY
                        state = STATE_RECORD
                        draw_record_detail()
                        continue

                # Otherwise handle as normal tap
                handle_day_touch(x, y)

        elif state == STATE_RECORD:
            # Check back button immediately (no drag needed)
            if BACK_X <= x <= BACK_X + BACK_W and BACK_Y <= y <= BACK_Y + BACK_H:
                detail_scroll_offset = 0
                if previous_state == STATE_SEARCH_RESULTS:
                    state = STATE_SEARCH_RESULTS
                    draw_search_results()
                else:
                    state = STATE_DAY
                    draw_day_view()
                wait_for_touch_release()
                continue

            # Track vertical drag for scrolling detail view
            drag_start_y = y
            last_drag_y = y
            pending_delta = 0
            dragged = False
            _last_drag_redraw = time.ticks_ms()
            while True:
                touch_point = read_touch()
                if touch_point is None:
                    break

                current_y = touch_point[1]
                if abs(current_y - drag_start_y) >= DRAG_REDRAW_PX:
                    dragged = True

                pending_delta += last_drag_y - current_y
                now = time.ticks_ms()
                redraw_due = time.ticks_diff(now, _last_drag_redraw) >= DRAG_REDRAW_MS
                if abs(pending_delta) >= DRAG_REDRAW_PX and redraw_due:
                    max_offset = _max_detail_scroll_offset()
                    new_offset = min(max(0, detail_scroll_offset + pending_delta), max_offset)
                    if new_offset != detail_scroll_offset:
                        detail_scroll_offset = new_offset
                        draw_record_detail()
                        _last_drag_redraw = now
                    pending_delta = 0

                last_drag_y = current_y
                time.sleep(0.01)

            if dragged and pending_delta:
                max_offset = _max_detail_scroll_offset()
                new_offset = min(max(0, detail_scroll_offset + pending_delta), max_offset)
                if new_offset != detail_scroll_offset:
                    detail_scroll_offset = new_offset
                    draw_record_detail()


# ============================================================================
# STARTUP
# ============================================================================

main()
