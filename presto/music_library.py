"""
Elm-style Presto Music Library application.

This is a standalone device entrypoint for the Pimoroni Presto. It retains the
Music Library screens and API behavior from ``main.py``, while routing user
input and blocking hardware work through messages and effects in the style of
``poc.py``. Deploy this file to the device as ``main.py``.
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

# Setup for the Presto display in full-resolution 480x480 mode.
presto = Presto(full_res=True)
display = presto.display
WIDTH, HEIGHT = display.get_bounds()
touch = presto.touch


UI_SCALE = 2
TEXT_SCALE = UI_SCALE
TITLE_TEXT_SCALE = UI_SCALE
PLACEHOLDER_TEXT_SCALE = UI_SCALE * 2


def px(value):
    """Scale a low-resolution layout measurement to full-resolution pixels."""
    return value * UI_SCALE


TEXT_H = px(8)
TEXT_LINE_H = px(12)
TITLE_LINE_H = px(14)

# Calendar layout (computed from display bounds)
CELL_GAP = px(3)
CELLS_PER_ROW = 7
MAX_ROWS = 6

# Header
HEADER_Y = 0
HEADER_H = px(31)
HEADER_TEXT_H = px(14)
HEADER_SIDE_MARGIN = px(8)
HEADER_BUTTON_W = px(32)
HEADER_BUTTON_H = px(25)
HEADER_BUTTON_Y = HEADER_Y + (HEADER_H - HEADER_BUTTON_H) // 2
ARROW_W = HEADER_BUTTON_W
ARROW_H = HEADER_BUTTON_H

# Day-of-week labels
DOW_Y = HEADER_Y + HEADER_H + px(2)
DOW_H = px(16)

# Grid starts after day-of-week labels with a small gap
CALENDAR_TOP = DOW_Y + DOW_H + px(6)

# Day cells: fit 7 across with comfortable side margins
CELL_SIZE_BY_WIDTH = (WIDTH - px(16) - (CELLS_PER_ROW - 1) * CELL_GAP) // CELLS_PER_ROW
CELL_SIZE_BY_HEIGHT = (
    HEIGHT - CALENDAR_TOP - px(8) - (MAX_ROWS - 1) * CELL_GAP
) // MAX_ROWS
CELL_SIZE = min(CELL_SIZE_BY_WIDTH, CELL_SIZE_BY_HEIGHT, px(78))
GRID_LEFT = (WIDTH - (CELLS_PER_ROW * CELL_SIZE + (CELLS_PER_ROW - 1) * CELL_GAP)) // 2

# Day view (proportional to cell size)
BACK_X = HEADER_SIDE_MARGIN
BACK_Y = HEADER_BUTTON_Y
BACK_W = HEADER_BUTTON_W
BACK_H = HEADER_BUTTON_H
DAY_HEADER_Y = HEADER_Y
DAY_HEADER_H = HEADER_H
DAY_HEADER_TEXT_H = HEADER_TEXT_H
DAY_COUNT_TEXT_H = TEXT_H
SCROLL_VIEWPORT_X = 0
SCROLL_VIEWPORT_Y = DAY_HEADER_Y + DAY_HEADER_H
SCROLL_VIEWPORT_W = WIDTH
SCROLL_VIEWPORT_H = HEIGHT - SCROLL_VIEWPORT_Y

# Detail view
DETAIL_COVER_SIZE = px(200)
DETAIL_COVER_X = (WIDTH - DETAIL_COVER_SIZE) // 2
DETAIL_COVER_Y = DAY_HEADER_Y + DAY_HEADER_H + px(12)
DETAIL_INFO_GAP = px(4)
DETAIL_TEXT_X = px(40)
DETAIL_TEXT_W = WIDTH - (2 * DETAIL_TEXT_X)

# Scrobble button (detail view)
SCROBBLE_BUTTON_W = px(200)
SCROBBLE_BUTTON_H = px(40)
SCROBBLE_BUTTON_GAP = px(12)  # vertical gap before button

RECORD_START_Y = DAY_HEADER_Y + DAY_HEADER_H + px(8)
THUMB_SIZE = px(40)
THUMB_MARGIN = px(8)
ROW_PAD_Y = px(8)
ROW_SEPARATOR_H = px(1)
TEXT_X = THUMB_MARGIN + THUMB_SIZE + px(12)
TEXT_W = WIDTH - TEXT_X - px(12)

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

# Scrobble button colors
SCROBBLE_BG = (55, 65, 81)         # Same slate as HOME_BTN_BG
SCROBBLE_TEXT = (228, 228, 231)    # Same as TITLE_COLOR
SCROBBLE_DONE_BG = (34, 197, 94)   # Green success
SCROBBLE_DONE_TEXT = (255, 255, 255)

# Days of week (Monday first, ISO 8601)
DAY_NAMES = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
MONTH_NAMES = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December",
]

# Touch debounce (milliseconds)
DEBOUNCE_MS = 300
KEYBOARD_DEBOUNCE_MS = 80
DRAG_REDRAW_MS = 40
DRAG_REDRAW_PX = px(8)

# WiFi connection timeout (seconds)
WIFI_TIMEOUT = 30

# Display sleep
DISPLAY_SLEEP_MS = 60_000
DISPLAY_BRIGHTNESS = 1.0
DISPLAY_SLEEP_BRIGHTNESS = 0.0
DISPLAY_FADE_MS = 500
DISPLAY_FADE_STEPS = 20
LOOP_SLEEP_MS = 30
WIFI_RETRY_MS = 10_000

# Home screen
HOME_TITLE = "Music Library"
HOME_TITLE_Y = px(60)
HOME_BUTTON_W = WIDTH - px(80)
HOME_BUTTON_H = px(50)
HOME_BUTTON_X = px(40)
HOME_BUTTON1_Y = px(120)
HOME_BUTTON2_Y = HOME_BUTTON1_Y + HOME_BUTTON_H + px(10)
HOME_BTN_BG = (55, 65, 81)  # Slate blue — distinct from BG and CELL_BG

# On-screen keyboard
KB_MARGIN = px(20)
KB_KEY_GAP = px(3)
KB_KEY_H = px(36)
KB_KEY_W = (WIDTH - 2 * KB_MARGIN - 9 * KB_KEY_GAP) // 10

KB_INPUT_Y = px(42)
KB_INPUT_H = px(28)
KB_INPUT_MARGIN = px(40)
KB_INPUT_X = KB_INPUT_MARGIN
KB_INPUT_W = WIDTH - (2 * KB_INPUT_MARGIN)
KB_INPUT_UPDATE_X = 0
KB_INPUT_UPDATE_Y = KB_INPUT_Y
KB_INPUT_UPDATE_W = WIDTH
KB_INPUT_UPDATE_H = KB_INPUT_H
KB_ROWS_START_Y = KB_INPUT_Y + KB_INPUT_H + px(12)

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
# STATE
# ============================================================================

# View state constants
STATE_MONTH = 0
STATE_DAY = 1
STATE_RECORD = 2
STATE_HOME = 3
STATE_SEARCH_INPUT = 4
STATE_SEARCH_RESULTS = 5
STATE_STATUS = 6


class DayListState:
    """Mutable state for the day records list."""

    def __init__(self):
        self.selected_day = 0
        self.records = []
        self.error = False
        self.scroll_offset = 0
        self.content_height = 0


class SearchState:
    """Mutable state for search input and search results."""

    def __init__(self):
        self.query = ""
        self.results = []
        self.error = False
        self.scroll_offset = 0
        self.content_height = 0
        self.keyboard_mode = "alpha"


class DetailState:
    """Mutable state for the record detail view."""

    def __init__(self):
        self.selected_index = None
        self.source_screen = None
        self.scroll_offset = 0
        self.content_height = 0
        self.scrobble_state = "idle"


class TouchState:
    """Mutable state for touch debounce, drag, and display sleep."""

    def __init__(self):
        self.last_touch = 0
        self.last_drag_redraw = 0
        self.dragging = False
        self.last_activity = 0
        self.display_awake = True
        self.consume_until_release = False
        self.gesture_screen = None
        self.start_x = 0
        self.start_y = 0
        self.last_y = 0
        self.pending_delta = 0
        self.dragged = False
        self.redrew_drag = False


class Model:
    """Navigation and interaction state transitioned by ``update()``."""

    def __init__(self):
        self.api_token = ""
        self.screen = STATE_HOME
        self.status_message = "Music Library\nStarting up..."
        self.next_wifi_retry_ms = 0
        self.today_year = 2026
        self.today_month = 5
        self.today_day = 1
        self.view_year = 2026
        self.view_month = 5
        self.day = DayListState()
        self.search = SearchState()
        self.detail = DetailState()
        self.touch = TouchState()


class Runtime:
    """Hardware polling state kept outside the application model."""

    def __init__(self):
        self.touch_down = False


# Compatibility name for direct renderer smoke tests.
AppState = Model


# Messages
MSG_BOOT = 1
MSG_WIFI_CONNECTED = 2
MSG_WIFI_FAILED = 3
MSG_TIME_SYNCED = 4
MSG_WIFI_RETRY = 5
MSG_TOUCH_DOWN = 6
MSG_TOUCH_MOVE = 7
MSG_TOUCH_UP = 8
MSG_IDLE_TIMEOUT = 9
MSG_WAKE_COMPLETE = 10
MSG_DAY_LOADED = 11
MSG_SEARCH_LOADED = 12
MSG_DETAIL_READY = 13
MSG_SCROBBLED = 14

# Effects
FX_RENDER = 1
FX_RENDER_PARTIAL = 2
FX_RENDER_QUERY = 3
FX_RENDER_SCROBBLE = 4
FX_CONNECT_WIFI = 5
FX_SYNC_TIME = 6
FX_LOAD_DAY = 7
FX_LOAD_SEARCH = 8
FX_PREPARE_DETAIL = 9
FX_SCROBBLE = 10
FX_SLEEP_DISPLAY = 11
FX_WAKE_DISPLAY = 12
FX_COLLECT_GARBAGE = 13

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

# Scrobble button pens
_pen_scrobble_bg = None
_pen_scrobble_text = None
_pen_scrobble_done_bg = None
_pen_scrobble_done_text = None


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

    # Scrobble button
    global _pen_scrobble_bg, _pen_scrobble_text
    global _pen_scrobble_done_bg, _pen_scrobble_done_text
    _pen_scrobble_bg = display.create_pen(*SCROBBLE_BG)
    _pen_scrobble_text = display.create_pen(*SCROBBLE_TEXT)
    _pen_scrobble_done_bg = display.create_pen(*SCROBBLE_DONE_BG)
    _pen_scrobble_done_text = display.create_pen(*SCROBBLE_DONE_TEXT)


# ============================================================================
# HELPER: DISPLAY UPDATES
# ============================================================================

def _display_update():
    """Push the full display buffer to the screen."""
    presto.update()


def _partial_display_update(x, y, w, h):
    """Push a bounded display region, falling back to a full update."""
    if w <= 0 or h <= 0:
        return

    try:
        presto.partial_update(x, y, w, h)
    except Exception:
        _display_update()


def _clear_region(x, y, w, h):
    """Clear a bounded display region to the app background."""
    display.set_pen(_pen_bg)
    display.rectangle(x, y, w, h)


def _clear_scroll_viewport():
    """Clear the scrollable content area below the fixed header."""
    _clear_region(SCROLL_VIEWPORT_X, SCROLL_VIEWPORT_Y,
                  SCROLL_VIEWPORT_W, SCROLL_VIEWPORT_H)


def _partial_scroll_viewport_update():
    """Push the scrollable content area below the fixed header."""
    _partial_display_update(SCROLL_VIEWPORT_X, SCROLL_VIEWPORT_Y,
                            SCROLL_VIEWPORT_W, SCROLL_VIEWPORT_H)


# ============================================================================
# HELPER: TEXT WRAPPING
# ============================================================================

def draw_wrapped(text, x, y, max_width, pen, scale=TEXT_SCALE):
    """Draw text, wrapping at word boundaries to fit within max_width pixels.

    PicoGraphics doesn't support automatic wrapping, so we manually break
    long strings. Returns the Y position after the last line drawn.
    """
    lines = _wrapped_lines(text, max_width, scale=scale)

    line_height = _text_line_height(scale)
    cy = y
    display.set_pen(pen)
    for line in lines:
        display.text(line, x, cy, scale=scale)
        cy += line_height

    return cy


def draw_wrapped_lines(lines, x, y, pen, scale=TEXT_SCALE):
    """Draw pre-wrapped text lines and return the Y position after them."""
    line_height = _text_line_height(scale)
    cy = y
    display.set_pen(pen)
    for line in lines:
        display.text(line, x, cy, scale=scale)
        cy += line_height

    return cy


def _text_line_height(scale=TEXT_SCALE):
    """Return a bitmap8 line height including scaled inter-line spacing."""
    return 8 * scale + px(4)


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


def _wrapped_line_count(text, max_width, scale=TEXT_SCALE):
    """Return how many wrapped lines the text will occupy."""
    return max(1, len(_wrapped_lines(text, max_width, scale=scale)))


def _wrapped_lines(text, max_width, scale=TEXT_SCALE):
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

def connect_wifi_effect(app):
    """Connect to WiFi and return ``(connected, detail, api_token)``."""
    try:
        import secrets
    except ImportError:
        return False, "ERROR: secrets.py not found.\nCopy config.example.py to secrets.py", ""

    ssid = getattr(secrets, "WIFI_SSID", "")
    password = getattr(secrets, "WIFI_PASSWORD", "")
    api_token = getattr(secrets, "API_TOKEN", "")

    if not ssid:
        return False, "ERROR: WIFI_SSID not set in secrets.py", api_token
    if not api_token:
        return False, "ERROR: API_TOKEN not set in secrets.py", api_token

    wlan = network.WLAN(network.STA_IF)
    wlan.active(True)

    if wlan.isconnected():
        return True, wlan.ifconfig()[0], api_token

    wlan.connect(ssid, password)

    elapsed = 0
    while not wlan.isconnected() and elapsed < WIFI_TIMEOUT:
        time.sleep(0.5)
        elapsed += 0.5

    if wlan.isconnected():
        return True, wlan.ifconfig()[0], api_token

    return (
        False,
        "WiFi connection failed.\nCheck credentials.\nRetrying in 10 seconds...",
        api_token,
    )


def sync_time_effect():
    """Synchronise system time via NTP and return the available date."""
    try:
        ntptime.settime()
    except Exception:
        pass
    return current_date()


def current_date():
    """Read the current calendar date from the system clock."""
    lt = time.localtime()
    return lt[0], lt[1], lt[2]


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


def sleep_display_effect():
    """Turn off the display backlight with a gradual fade."""
    _fade_backlight(DISPLAY_BRIGHTNESS, DISPLAY_SLEEP_BRIGHTNESS)


def wake_display_effect(app):
    """Restore backlight, refresh the date, and best-effort reconnect WiFi."""
    _fade_backlight(DISPLAY_SLEEP_BRIGHTNESS, DISPLAY_BRIGHTNESS)

    if not wifi_connected():
        connect_wifi_effect(app)

    return current_date()


def wifi_connected():
    """Return True if the WLAN interface is currently connected."""
    try:
        wlan = network.WLAN(network.STA_IF)
        wlan.active(True)
        return wlan.isconnected()
    except Exception:
        return False


# ============================================================================
# API CLIENT
# ============================================================================

def _auth_header(app):
    """Return the Authorization header dict for urequests."""
    return {"Authorization": "Bearer " + app.api_token}


def fetch_records(app, year, month, day):
    """Fetch records released on the given date from the API.

    Returns (records_list, error_flag).
    - On success: (list_of_dicts, False)
    - On failure: ([], True)
    """
    date_str = make_date_string(year, month, day)
    url = API_BASE + "/api/v1/collection/on_this_day?date=" + date_str

    try:
        resp = urequests.get(url, headers=_auth_header(app))
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


def fetch_search_results(app, query):
    """Fetch search results from the API.

    Returns (records_list, error_flag). Same shape as fetch_records().
    """
    # urequests doesn't have url-encode built-in; hand-encode common chars
    encoded = query.replace(" ", "+")
    url = API_BASE + "/api/v1/collection?q=" + encoded + "&limit=20"

    try:
        resp = urequests.get(url, headers=_auth_header(app))
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


def fetch_thumbnail(app, url):
    """Fetch a JPEG thumbnail from the given URL.

    Returns the raw bytes on success, None on failure.
    """
    try:
        resp = urequests.get(url, headers=_auth_header(app))
        if resp.status_code == 200:
            data = resp.content
            resp.close()
            return data
        resp.close()
    except Exception:
        pass
    return None


# ============================================================================
# EFFECT DATA PREPARATION
# ============================================================================

def load_day_effect(app, year, month, day):
    """Load and prepare a day list before it becomes visible."""
    if not ensure_wifi_connected_effect(app):
        return MSG_DAY_LOADED, [], True, 0

    recs, had_error = fetch_records(app, year, month, day)
    content_height = 0 if had_error else prepare_record_list(app, recs)
    return MSG_DAY_LOADED, recs, had_error, content_height


def load_search_effect(app, query):
    """Load and prepare search results before they become visible."""
    if not ensure_wifi_connected_effect(app):
        return MSG_SEARCH_LOADED, [], True, 0

    recs, had_error = fetch_search_results(app, query)
    content_height = 0 if had_error else prepare_record_list(app, recs)
    return MSG_SEARCH_LOADED, recs, had_error, content_height


def ensure_wifi_connected_effect(app):
    """Reconnect as part of request effects when the interface dropped."""
    if wifi_connected():
        return True

    connected, _detail, _api_token = connect_wifi_effect(app)
    return connected


def selected_record(app):
    """Return the record selected for the detail screen."""
    if app.detail.source_screen == STATE_SEARCH_RESULTS:
        return app.search.results[app.detail.selected_index]
    return app.day.records[app.detail.selected_index]


def prepare_detail_effect(app):
    """Prepare detail layout and medium cover bytes outside rendering."""
    rec = dict(selected_record(app))
    content_height = _measure_detail_content(app, rec)
    cover_url = _record_detail_cover_url(rec)

    if cover_url and rec.get("_detail_thumb_data", None) is None:
        if not rec.get("_detail_thumb_failed", False):
            data = fetch_thumbnail(app, cover_url)
            if data is None:
                rec["_detail_thumb_failed"] = True
            else:
                rec["_detail_thumb_data"] = data

    return MSG_DETAIL_READY, content_height, rec


def scrobble_effect(app, rec):
    """Post a scrobble request and return whether it succeeded."""
    rec_id = rec.get("id")
    if not rec_id:
        return MSG_SCROBBLED, False

    url = API_BASE + "/api/v1/collection/" + str(rec_id) + "/scrobble"
    succeeded = False
    try:
        resp = urequests.post(url, headers=_auth_header(app))
        succeeded = resp.status_code == 200
        resp.close()
    except Exception:
        succeeded = False

    gc.collect()
    return MSG_SCROBBLED, succeeded


def _close_jpeg(jpeg):
    """Release a jpegdec object if the firmware exposes close()."""
    if jpeg is None:
        return

    try:
        jpeg.close()
    except Exception:
        pass


def draw_jpeg(data, x, y, placeholder_w, placeholder_h):
    """Decode and draw an API-sized JPEG image at x, y.

    Uses jpegdec module (standard on Pimoroni firmware).
    Falls back to a placeholder rectangle on failure.
    """
    if data is None:
        _draw_placeholder(x, y, placeholder_w, placeholder_h)
        return

    # Try jpegdec module.
    if _HAS_JPEGDEC:
        jpeg = None
        try:
            jpeg = _jpegdec_lib.JPEG(display)
            try:
                jpeg.open_RAM(memoryview(data))
            except Exception:
                jpeg.open_RAM(data)

            try:
                jpeg.decode(x, y)
            except TypeError:
                # Older firmware expects a third full-size decode argument.
                jpeg.decode(x, y, 0)
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
    _draw_placeholder(x, y, placeholder_w, placeholder_h)


def _draw_placeholder(x, y, w, h):
    """Draw a grey placeholder rectangle with a question mark."""
    display.set_pen(_pen_placeholder)
    display.rectangle(x, y, w, h)
    display.set_pen(_pen_dim_text)
    cx = x + w // 2 - display.measure_text("?", scale=PLACEHOLDER_TEXT_SCALE) // 2
    cy = y + h // 2 - px(10)
    display.text("?", cx, cy, scale=PLACEHOLDER_TEXT_SCALE)


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
    line_h = px(20)
    total_h = len(lines) * line_h
    start_y = (HEIGHT - total_h) // 2

    for i, line in enumerate(lines):
        w = display.measure_text(line, scale=TEXT_SCALE)
        x = (WIDTH - w) // 2
        display.text(line, x, start_y + i * line_h, scale=TEXT_SCALE)

    _display_update()


# ============================================================================
# DRAWING: MONTH CALENDAR
# ============================================================================

def draw_month_view(app):
    """Render the full month calendar view including header, day-of-week
    labels, day grid, and today highlight."""
    display.set_pen(_pen_bg)
    display.clear()

    _draw_month_header(app)
    _draw_day_labels()
    _draw_day_grid(app)
    _display_update()


HOME_BTN_W = px(30)
HOME_BTN_H = px(25)
HOME_BTN_Y = HEADER_Y + (HEADER_H - HOME_BTN_H) // 2


def _draw_month_header(app):
    """Draw the month/year title, navigation arrows, and Home button."""
    # Background bar
    display.set_pen(_pen_cell_bg)
    display.rectangle(0, HEADER_Y, WIDTH, HEADER_H)

    # Month and year text (centered between arrow buttons)
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    title = "{} {}".format(MONTH_NAMES[app.view_month - 1], app.view_year)
    tw = display.measure_text(title, scale=TEXT_SCALE)
    # Left boundary: after Home + left-arrow; right boundary: before right-arrow
    title_left = HEADER_SIDE_MARGIN + HOME_BTN_W + px(4) + ARROW_W
    title_right = WIDTH - ARROW_W - HEADER_SIDE_MARGIN
    title_area = title_right - title_left
    tx = title_left + (title_area - tw) // 2
    ty = HEADER_Y + (HEADER_H - HEADER_TEXT_H) // 2
    display.text(title, tx, ty, scale=TEXT_SCALE)

    # Home button (leftmost)
    hx = HEADER_SIDE_MARGIN
    hy = HOME_BTN_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(hx, hy, HOME_BTN_W, HOME_BTN_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text("H", hx, hy, HOME_BTN_W, HOME_BTN_H, TEXT_H)

    # Left arrow (shifted right to make room for Home)
    lx = hx + HOME_BTN_W + px(4)
    ly = HEADER_BUTTON_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(lx, ly, ARROW_W, ARROW_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text("<", lx, ly, ARROW_W, ARROW_H, TEXT_H)

    # Right arrow
    rx = WIDTH - ARROW_W - HEADER_SIDE_MARGIN
    ry = HEADER_BUTTON_Y
    display.set_pen(_pen_placeholder)
    display.rectangle(rx, ry, ARROW_W, ARROW_H)
    display.set_pen(_pen_back)
    display.set_font("bitmap8")
    _draw_centered_text(">", rx, ry, ARROW_W, ARROW_H, TEXT_H)


def _draw_centered_text(text, x, y, w, h, text_h, scale=TEXT_SCALE):
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
        tw = display.measure_text(name, scale=TEXT_SCALE)
        display.text(name, cx - tw // 2, DOW_Y, scale=TEXT_SCALE)


def _draw_day_grid(app):
    """Draw the 7x6 grid of day cells for the current view month."""
    days = days_in_month(app.view_year, app.view_month)
    first_dow = day_of_week(app.view_year, app.view_month, 1)

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
                app.view_year == app.today_year
                and app.view_month == app.today_month
                and day_num == app.today_day
            )
            is_selected = (app.screen == STATE_DAY and day_num == app.day.selected_day)

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
    tw = display.measure_text(text, scale=TEXT_SCALE)
    display.text(text, cx - tw // 2, cy - px(5), scale=TEXT_SCALE)


# ============================================================================
# DRAWING: HOME SCREEN (splash)
# ============================================================================

def draw_home_screen(app):
    """Render the splash screen with two large touch targets."""
    display.set_pen(_pen_bg)
    display.clear()

    # Title
    display.set_pen(_pen_title)
    display.set_font("bitmap14_outline")
    tw = display.measure_text(HOME_TITLE, scale=TEXT_SCALE)
    display.text(HOME_TITLE, (WIDTH - tw) // 2, HOME_TITLE_Y, scale=TEXT_SCALE)

    # Buttons
    _draw_home_button(HOME_BUTTON1_Y, "Search Collection")
    _draw_home_button(HOME_BUTTON2_Y, "Today's Records")

    _display_update()


def _draw_home_button(y, label):
    """Draw a large rounded-rectangle button for the splash screen."""
    display.set_pen(_pen_home_btn)
    display.rectangle(HOME_BUTTON_X, y, HOME_BUTTON_W, HOME_BUTTON_H)
    display.set_pen(_pen_today_text)
    display.set_font("bitmap8")
    tw = display.measure_text(label, scale=TEXT_SCALE)
    tx = HOME_BUTTON_X + (HOME_BUTTON_W - tw) // 2
    ty = y + (HOME_BUTTON_H - TEXT_H) // 2
    display.text(label, tx, ty, scale=TEXT_SCALE)


# ============================================================================
# DRAWING: SEARCH INPUT (keyboard)
# ============================================================================

def draw_search_input(app):
    """Render the search input view with query field and on-screen keyboard."""
    display.set_pen(_pen_bg)
    display.clear()

    _draw_search_input_header()
    _draw_search_query_field(app)
    _draw_keyboard(app)
    _display_update()


def _draw_search_query_field(app):
    """Draw the search query field without touching the keyboard."""
    _clear_region(KB_INPUT_UPDATE_X, KB_INPUT_UPDATE_Y,
                  KB_INPUT_UPDATE_W, KB_INPUT_UPDATE_H)

    display.set_pen(_pen_cell_bg)
    display.rectangle(KB_INPUT_X, KB_INPUT_Y, KB_INPUT_W, KB_INPUT_H)
    display.set_pen(_pen_header_text)
    display.set_font("bitmap8")

    display_q = app.search.query if app.search.query else "_"
    display.text(
        display_q,
        KB_INPUT_X + px(8),
        KB_INPUT_Y + px(12),
        scale=TEXT_SCALE
    )


def _redraw_search_query_field(app):
    """Redraw and push only the search query field row."""
    _draw_search_query_field(app)
    _partial_display_update(KB_INPUT_UPDATE_X, KB_INPUT_UPDATE_Y,
                            KB_INPUT_UPDATE_W, KB_INPUT_UPDATE_H)


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
    tw = display.measure_text(title, scale=TEXT_SCALE)
    display.text(title, (WIDTH - tw) // 2,
                 DAY_HEADER_Y + (DAY_HEADER_H - DAY_HEADER_TEXT_H) // 2, scale=TEXT_SCALE)


def _draw_keyboard(app):
    """Draw the on-screen QWERTY or numbers keyboard."""
    display.set_font("bitmap8")
    keys_matrix = ALPHA_KEYS if app.search.keyboard_mode == "alpha" else NUM_KEYS
    toggle_label = "123" if app.search.keyboard_mode == "alpha" else "ABC"

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
    ok_pen = _pen_dim_text if app.search.query.strip() == "" else _pen_header_text
    _draw_key(bx, cy, "OK", bottom_w, KB_KEY_H, text_pen=ok_pen)


def _draw_key(x, y, label, w, h, text_pen=None):
    """Draw a single keyboard key as a rounded rectangle with centered label."""
    display.set_pen(_pen_cell_bg)
    display.rectangle(x, y, w, h)
    pen = text_pen if text_pen is not None else _pen_normal_text
    display.set_pen(pen)
    tw = display.measure_text(label, scale=TEXT_SCALE)
    tx = x + (w - tw) // 2
    ty = y + (h - TEXT_H) // 2
    display.text(label, tx, ty, scale=TEXT_SCALE)


def _keyboard_hit_test(app, x, y):
    """Map a touch (x, y) to a keyboard action.

    Returns: a character string, "toggle", "space", "backspace", "ok", or None.
    """
    if y < KB_ROWS_START_Y:
        return None

    keys_matrix = ALPHA_KEYS if app.search.keyboard_mode == "alpha" else NUM_KEYS

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
    _partial_display_update(kx, ky, kw, kh)
    time.sleep(0.05)


# ============================================================================
# DRAWING: SEARCH RESULTS
# ============================================================================

def draw_search_results(app, partial=False):
    """Render the search results view, reusing record-list rendering."""
    if partial:
        _clear_scroll_viewport()
    else:
        display.set_pen(_pen_bg)
        display.clear()

        _draw_search_results_header(app)

    if app.search.error:
        _draw_search_error()
        if partial:
            _partial_scroll_viewport_update()
        else:
            _display_update()
        return

    if not app.search.results:
        _draw_search_empty()
        if partial:
            _partial_scroll_viewport_update()
        else:
            _display_update()
        return

    _set_clip_below_header()
    _draw_search_record_list(app)
    _remove_clip()
    if partial:
        _partial_scroll_viewport_update()
    else:
        _display_update()


def _draw_search_results_header(app):
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
    # the stored search query so user can refine on Back
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    display_label = "Search: " + app.search.query
    max_w = WIDTH - (BACK_X + BACK_W + px(8)) - px(8)
    if display.measure_text(display_label, scale=TEXT_SCALE) > max_w:
        suffix = "..."
        display_q = app.search.query
        while (display.measure_text("Search: " + display_q + suffix, scale=TEXT_SCALE) > max_w
               and len(display_q) > 0):
            display_q = display_q[:-1]
        display_label = "Search: " + (display_q + suffix if display_q else suffix)
    tw = display.measure_text(display_label, scale=TEXT_SCALE)
    display.text(display_label, (WIDTH - tw) // 2,
                 DAY_HEADER_Y + (DAY_HEADER_H - DAY_HEADER_TEXT_H) // 2, scale=TEXT_SCALE)


def _draw_search_record_list(app):
    """Draw the scrollable search results list, mirroring day-view scroll."""
    max_offset = _search_max_scroll_offset(app)
    app.search.scroll_offset = min(max(0, app.search.scroll_offset), max_offset)

    # Up arrow if scrolled down
    if app.search.scroll_offset > 0:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        arrow_w = display.measure_text("^", scale=TEXT_SCALE)
        display.text("^", (WIDTH - arrow_w) // 2, DAY_HEADER_H + px(4), scale=TEXT_SCALE)

    cy = RECORD_START_Y - app.search.scroll_offset
    for rec in app.search.results:
        row_h = rec.get("_row_height", THUMB_SIZE + px(8))
        row_bottom = cy + row_h

        if row_bottom <= RECORD_START_Y:
            cy = row_bottom
            continue

        if cy >= HEIGHT - px(28):
            break

        _draw_record_row(app, rec, cy)
        cy = row_bottom

    # Down arrow if more records below
    if app.search.scroll_offset < max_offset:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        arrow_w = display.measure_text("v", scale=TEXT_SCALE)
        display.text("v", (WIDTH - arrow_w) // 2, HEIGHT - px(24), scale=TEXT_SCALE)


def _search_max_scroll_offset(app):
    """Return the maximum pixel scroll offset for search results."""
    viewport_h = HEIGHT - RECORD_START_Y - px(28)
    return max(0, app.search.content_height - viewport_h)


def _draw_search_empty():
    """Show 'No records found' message."""
    display.set_pen(_pen_dim_text)
    display.set_font("bitmap8")
    msg = "No records found"
    mw = display.measure_text(msg, scale=TEXT_SCALE)
    display.text(msg, (WIDTH - mw) // 2, HEIGHT // 2 - px(10), scale=TEXT_SCALE)


def _draw_search_error():
    """Show search error message with retry hint."""
    display.set_pen(_pen_error)
    display.set_font("bitmap8")
    msg = "Could not reach server"
    mw = display.measure_text(msg, scale=TEXT_SCALE)
    display.text(msg, (WIDTH - mw) // 2, HEIGHT // 2 - px(20), scale=TEXT_SCALE)

    display.set_pen(_pen_dim_text)
    hint = "Tap to retry"
    hw = display.measure_text(hint, scale=TEXT_SCALE)
    display.text(hint, (WIDTH - hw) // 2, HEIGHT // 2 + px(10), scale=TEXT_SCALE)


# ============================================================================
# DRAWING: DAY VIEW (records list)
# ============================================================================

def draw_day_view(app, partial=False):
    """Render the day view showing records for the selected date."""
    if partial:
        _clear_scroll_viewport()
    else:
        display.set_pen(_pen_bg)
        display.clear()

        _draw_day_header(app)

    if app.day.error:
        _draw_day_error()
        if partial:
            _partial_scroll_viewport_update()
        else:
            _display_update()
        return

    if not app.day.records:
        _draw_day_empty()
        if partial:
            _partial_scroll_viewport_update()
        else:
            _display_update()
        return

    _set_clip_below_header()
    _draw_record_list(app)
    _remove_clip()
    if partial:
        _partial_scroll_viewport_update()
    else:
        _display_update()


def _draw_day_header(app):
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
        MONTH_NAMES[app.view_month - 1], app.day.selected_day, app.view_year
    )
    display.set_pen(_pen_header_text)
    display.set_font("bitmap14_outline")
    tw = display.measure_text(date_str, scale=TEXT_SCALE)
    display.text(
        date_str,
        (WIDTH - tw) // 2,
        DAY_HEADER_Y + (DAY_HEADER_H - DAY_HEADER_TEXT_H) // 2,
        scale=TEXT_SCALE
    )

    # Record count
    record_count = len(app.day.records)
    count_str = "{} record{}".format(record_count, "s" if record_count != 1 else "")
    display.set_pen(_pen_dim_text)
    display.set_font("bitmap8")
    cw = display.measure_text(count_str, scale=TEXT_SCALE)
    display.text(
        count_str,
        WIDTH - cw - px(11),
        DAY_HEADER_Y + (DAY_HEADER_H - DAY_COUNT_TEXT_H) // 2,
        scale=TEXT_SCALE
    )


def _draw_day_error():
    """Show error message when API call failed."""
    display.set_pen(_pen_error)
    display.set_font("bitmap8")
    msg = "Could not reach server"
    mw = display.measure_text(msg, scale=TEXT_SCALE)
    display.text(msg, (WIDTH - mw) // 2, HEIGHT // 2 - px(20), scale=TEXT_SCALE)

    display.set_pen(_pen_dim_text)
    hint = "Tap < Back to return"
    hw = display.measure_text(hint, scale=TEXT_SCALE)
    display.text(hint, (WIDTH - hw) // 2, HEIGHT // 2 + px(10), scale=TEXT_SCALE)


def _draw_day_empty():
    """Show message when no records exist for the selected date."""
    display.set_pen(_pen_dim_text)
    display.set_font("bitmap8")
    msg = "No records on this day"
    mw = display.measure_text(msg, scale=TEXT_SCALE)
    display.text(msg, (WIDTH - mw) // 2, HEIGHT // 2 - px(10), scale=TEXT_SCALE)


def _draw_record_list(app):
    """Draw the scrollable list of record rows with cover thumbnails.
    Uses dynamic row heights so wrapped text doesn't break layout."""
    max_offset = _max_scroll_offset(app)
    app.day.scroll_offset = min(max(0, app.day.scroll_offset), max_offset)

    # Up arrow if scrolled down
    if app.day.scroll_offset > 0:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        arrow_w = display.measure_text("^", scale=TEXT_SCALE)
        display.text("^", (WIDTH - arrow_w) // 2, DAY_HEADER_H + px(4), scale=TEXT_SCALE)

    cy = RECORD_START_Y - app.day.scroll_offset

    for rec in app.day.records:
        row_h = rec.get("_row_height", THUMB_SIZE + px(8))
        row_bottom = cy + row_h

        if row_bottom <= RECORD_START_Y:
            cy = row_bottom
            continue

        if cy >= HEIGHT - px(28):
            break

        _draw_record_row(app, rec, cy)
        cy = row_bottom

    # Down arrow if more records below
    if app.day.scroll_offset < max_offset:
        display.set_pen(_pen_arrow)
        display.set_font("bitmap14_outline")
        arrow_w = display.measure_text("v", scale=TEXT_SCALE)
        display.text("v", (WIDTH - arrow_w) // 2, HEIGHT - px(24), scale=TEXT_SCALE)

def _max_scroll_offset(app):
    """Return the maximum pixel scroll offset for the current records."""
    viewport_h = HEIGHT - RECORD_START_Y - px(28)
    return max(0, app.day.content_height - viewport_h)


def prepare_record_list(app, recs):
    """Cache display fields, row heights, and thumbnails for a record list.

    Returns the list content height for the caller's view state.
    """
    display.set_font("bitmap8")

    content_height = 0
    for rec in recs:
        _prepare_record_for_display(rec)
        content_height += rec.get("_row_height", THUMB_SIZE + px(8))

    preload_record_thumbnails(app, recs)
    gc.collect()
    return content_height


def _prepare_record_for_display(rec):
    """Prepare one record's display text and row height."""
    title = display_text(rec.get("title", "Unknown Title"))
    artists = rec.get("artists", [])
    artist_str = display_text(", ".join(artists)) if artists else ""
    meta_text = _record_meta_text(rec)

    rec["_display_title"] = title
    rec["_display_artists"] = artist_str
    rec["_display_meta"] = meta_text
    rec["_display_title_lines"] = _wrapped_lines(title, TEXT_W, scale=TEXT_SCALE)
    rec["_display_artist_lines"] = (
        _wrapped_lines(artist_str, TEXT_W, scale=TEXT_SCALE) if artist_str else []
    )
    rec["_display_meta_lines"] = (
        _wrapped_lines(meta_text, TEXT_W, scale=TEXT_SCALE) if meta_text else []
    )
    rec["_thumb_url"] = _record_thumbnail_url(rec)
    rec["_row_height"] = _record_row_height(rec)


def preload_record_thumbnails(app, recs):
    """Fetch thumbnail bytes before the first draw of a record list."""
    for rec in recs:
        if _record_thumbnail_url(rec):
            _record_thumbnail_data(app, rec)


def _record_row_height(rec):
    """Calculate a record row height without drawing it."""
    min_h = THUMB_SIZE + ROW_PAD_Y * 2 + ROW_SEPARATOR_H
    title_lines = rec.get("_display_title_lines", None)
    if title_lines is None:
        title = rec.get("_display_title", display_text(rec.get("title", "Unknown Title")))
        title_lines = _wrapped_lines(title, TEXT_W, scale=TEXT_SCALE)
    ty = max(1, len(title_lines)) * TEXT_LINE_H

    artist_lines = rec.get("_display_artist_lines", None)
    if artist_lines is None:
        artist_str = rec.get("_display_artists", "")
        artist_lines = _wrapped_lines(artist_str, TEXT_W, scale=TEXT_SCALE) if artist_str else []
    if artist_lines:
        ty += px(2) + len(artist_lines) * TEXT_LINE_H

    meta_lines = rec.get("_display_meta_lines", None)
    if meta_lines is None:
        meta_text = rec.get("_display_meta", _record_meta_text(rec))
        meta_lines = _wrapped_lines(meta_text, TEXT_W, scale=TEXT_SCALE) if meta_text else []
    if meta_lines:
        ty += px(2) + len(meta_lines) * TEXT_LINE_H

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


def _record_thumbnail_data(app, rec):
    """Fetch thumbnail bytes once per record and reuse them on redraw."""
    if rec.get("_thumb_failed", False):
        return None

    cached = rec.get("_thumb_data", None)
    if cached is not None:
        return cached

    thumb_url = rec.get("_thumb_url", "") or _record_thumbnail_url(rec)
    if not thumb_url:
        return None

    data = fetch_thumbnail(app, thumb_url)
    if data is None:
        rec["_thumb_failed"] = True
    else:
        rec["_thumb_data"] = data

    return data


def _record_thumbnail_url(rec):
    """Return the API-sized cover URL for a record row."""
    return _record_cover_url(rec, "small")


def _record_detail_cover_url(rec):
    """Return the API-sized cover URL for a record detail page."""
    return _record_cover_url(rec, "medium")


def _record_cover_url(rec, size):
    """Return a named cover URL from the API covers object."""
    covers = rec.get("covers", {})
    if not covers:
        return ""
    return covers.get(size, "") or ""


def _draw_record_row(app, rec, y):
    """Draw a single record row using its cached layout height."""
    row_h = rec.get("_row_height", None)
    if row_h is None:
        row_h = _record_row_height(rec)
    row_bottom = y + row_h

    # Fetch and draw thumbnail (top-aligned in row)
    thumb_y = y + ROW_PAD_Y
    if app.touch.dragging:
        _draw_placeholder(THUMB_MARGIN, thumb_y, THUMB_SIZE, THUMB_SIZE)
    else:
        jpeg_data = _record_thumbnail_data(app, rec)
        if jpeg_data is not None:
            draw_jpeg(jpeg_data, THUMB_MARGIN, thumb_y, THUMB_SIZE, THUMB_SIZE)
        else:
            _draw_placeholder(THUMB_MARGIN, thumb_y, THUMB_SIZE, THUMB_SIZE)

    # Title (starts at same height as thumbnail)
    display.set_font("bitmap8")
    ty = y + ROW_PAD_Y
    title_lines = rec.get("_display_title_lines", None)
    if title_lines is None:
        title = rec.get("_display_title", display_text(rec.get("title", "Unknown Title")))
        ty = draw_wrapped(title, TEXT_X, ty, TEXT_W, _pen_title, scale=TEXT_SCALE)
    else:
        ty = draw_wrapped_lines(title_lines, TEXT_X, ty, _pen_title, scale=TEXT_SCALE)

    # Artists
    artist_lines = rec.get("_display_artist_lines", None)
    if artist_lines is None:
        artist_str = rec.get("_display_artists", "")
        artist_lines = _wrapped_lines(artist_str, TEXT_W, scale=TEXT_SCALE) if artist_str else []
    if artist_lines:
        ty += px(2)
        ty = draw_wrapped_lines(artist_lines, TEXT_X, ty, _pen_artist, scale=TEXT_SCALE)

    meta_lines = rec.get("_display_meta_lines", None)
    if meta_lines is None:
        meta_text = rec.get("_display_meta", _record_meta_text(rec))
        meta_lines = _wrapped_lines(meta_text, TEXT_W, scale=TEXT_SCALE) if meta_text else []
    if meta_lines:
        ty += px(2)
        ty = draw_wrapped_lines(meta_lines, TEXT_X, ty, _pen_dim_text, scale=TEXT_SCALE)

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

def _max_detail_scroll_offset(app):
    """Return the maximum pixel scroll offset for the detail view."""
    if app.detail.content_height == 0:
        return 0
    content_bottom = DETAIL_COVER_Y + app.detail.content_height
    return max(0, content_bottom - HEIGHT)


def _measure_detail_text_height(text, font="bitmap8", scale=TEXT_SCALE, max_w=None):
    """Return the pixel height that text would occupy when drawn wrapped."""
    if max_w is None:
        max_w = DETAIL_TEXT_W
    lines = _wrapped_lines(text, max_w, scale=scale)
    line_height = _line_height_for_font(font, scale)
    return len(lines) * line_height


def _line_height_for_font(font, scale=TEXT_SCALE):
    """Return scaled line height for the bitmap font used by a detail section."""
    if font == "bitmap14_outline":
        return 14 * scale
    return _text_line_height(scale)


def _line_metrics(lines, font="bitmap8", scale=TEXT_SCALE):
    """Pair pre-wrapped text lines with their measured widths."""
    display.set_font(font)
    metrics = []
    for line in lines:
        metrics.append((line, display.measure_text(line, scale=scale)))
    return metrics


def _measure_detail_content(app, rec):
    """Compute display caches and return scrollable detail content height."""
    h = 0

    # Title (above cover)
    title = rec.get("_display_title",
                    display_text(rec.get("title", "Unknown Title")))
    display.set_font("bitmap14_outline")
    title_lines = _wrapped_lines(title, DETAIL_TEXT_W, scale=TEXT_SCALE)
    rec["_detail_title_lines"] = _line_metrics(
        title_lines, font="bitmap14_outline", scale=TEXT_SCALE
    )
    h += len(title_lines) * TITLE_LINE_H
    h += px(6)

    # Artists (above cover)
    artist_str = rec.get("_display_artists", "")
    if not artist_str:
        artists = rec.get("artists", [])
        artist_str = display_text(", ".join(artists)) if artists else ""
    if artist_str:
        display.set_font("bitmap8")
        artist_lines = _wrapped_lines(artist_str, DETAIL_TEXT_W, scale=TEXT_SCALE)
        rec["_detail_artist_lines"] = _line_metrics(artist_lines, scale=TEXT_SCALE)
        h += len(artist_lines) * TEXT_LINE_H
        h += px(4)
    else:
        rec["_detail_artist_lines"] = []

    h += DETAIL_INFO_GAP  # gap before cover

    # Cover
    h += DETAIL_COVER_SIZE
    h += DETAIL_INFO_GAP

    # Genres (below cover)
    genres = rec.get("genres", [])
    if genres:
        genre_str = display_text(", ".join(genres))
        display.set_font("bitmap8")
        genre_lines = _wrapped_lines(genre_str, DETAIL_TEXT_W, scale=TEXT_SCALE)
        rec["_detail_genre_lines"] = _line_metrics(genre_lines, scale=TEXT_SCALE)
        h += len(genre_lines) * TEXT_LINE_H
        h += px(4)
    else:
        rec["_detail_genre_lines"] = []

    h += px(6)

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
        display.set_font("bitmap8")
        meta_lines = _wrapped_lines(meta_str, DETAIL_TEXT_W, scale=TEXT_SCALE)
        rec["_detail_meta_lines"] = _line_metrics(meta_lines, scale=TEXT_SCALE)
        h += len(meta_lines) * TEXT_LINE_H
        h += px(4)
    else:
        rec["_detail_meta_lines"] = []

    # Purchased at
    purchased_at = rec.get("purchased_at", "")
    if purchased_at:
        purch_str = "Purchased: " + display_text(str(purchased_at)[:10])
        display.set_font("bitmap8")
        purchased_lines = _wrapped_lines(purch_str, DETAIL_TEXT_W, scale=TEXT_SCALE)
        rec["_detail_purchased_lines"] = _line_metrics(purchased_lines, scale=TEXT_SCALE)
        h += len(purchased_lines) * TEXT_LINE_H
    else:
        rec["_detail_purchased_lines"] = []

    # Scrobble button (at bottom, only if scrobble-eligible)
    if rec.get("selected_release_id"):
        h += SCROBBLE_BUTTON_GAP
        h += SCROBBLE_BUTTON_H

    return h


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


def draw_record_detail(app, partial=False):
    """Render the individual record detail view. Layout order:
    title, artists, large cover, genres, metadata, purchased at."""
    if partial:
        _clear_scroll_viewport()
    else:
        display.set_pen(_pen_bg)
        display.clear()

    if app.detail.source_screen == STATE_SEARCH_RESULTS:
        rec = app.search.results[app.detail.selected_index]
    else:
        rec = app.day.records[app.detail.selected_index]

    # The application prepares layout as an effect; direct smoke draws fall
    # back to preparing once and drag redraws only consume cached values.
    if app.detail.content_height == 0:
        app.detail.content_height = _measure_detail_content(app, rec)

    # Clamp scroll offset
    max_off = _max_detail_scroll_offset(app)
    if app.detail.scroll_offset > max_off:
        app.detail.scroll_offset = max_off
    if app.detail.scroll_offset < 0:
        app.detail.scroll_offset = 0

    offset = app.detail.scroll_offset

    if not partial:
        _draw_detail_header()

    # Clip scrolling content below the header
    _set_clip_below_header()

    # Start drawing below the header
    y = DETAIL_COVER_Y - offset

    # Title and artists (above cover)
    y = _draw_detail_title_artists(rec, y)
    y += DETAIL_INFO_GAP  # gap before cover

    # Cover image
    _draw_detail_cover(app, rec, y)

    # Genres, metadata, purchased at (below cover)
    y = y + DETAIL_COVER_SIZE + DETAIL_INFO_GAP
    _draw_detail_info_below_cover(rec, y)

    # Scrobble button (at bottom of content, only if eligible)
    if rec.get("selected_release_id"):
        button_y = _detail_scrobble_button_y(app)
        # Only draw if the button is at least partially visible
        if (button_y + SCROBBLE_BUTTON_H > DAY_HEADER_Y + DAY_HEADER_H
                and button_y < HEIGHT):
            _draw_scrobble_button(app, rec, button_y)

    # Scroll indicators
    display.set_font("bitmap14_outline")
    if offset > 0:
        display.set_pen(_pen_arrow)
        arrow_w = display.measure_text("^", scale=TEXT_SCALE)
        display.text("^", (WIDTH - arrow_w) // 2, DAY_HEADER_H + px(4), scale=TEXT_SCALE)
    if offset < max_off:
        display.set_pen(_pen_arrow)
        arrow_w = display.measure_text("v", scale=TEXT_SCALE)
        display.text("v", (WIDTH - arrow_w) // 2, HEIGHT - px(24), scale=TEXT_SCALE)

    _remove_clip()

    if partial:
        _partial_scroll_viewport_update()
    else:
        _display_update()


def _detail_scrobble_button_y(app):
    """Return the scrobble button Y position for the current detail offset."""
    return (DETAIL_COVER_Y - app.detail.scroll_offset
            + app.detail.content_height - SCROBBLE_BUTTON_H)


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
    tw = display.measure_text(label, scale=TEXT_SCALE)
    display.text(
        label,
        (WIDTH - tw) // 2,
        DAY_HEADER_Y + (DAY_HEADER_H - DAY_HEADER_TEXT_H) // 2,
        scale=TEXT_SCALE
    )


def _draw_detail_title_artists(rec, y):
    """Draw title and artists above the cover. Returns y after drawing."""
    # Title
    title_lines = rec.get("_detail_title_lines", None)
    if title_lines is None:
        title = rec.get("_display_title",
                        display_text(rec.get("title", "Unknown Title")))
        y = _draw_detail_text_line(title, y, _pen_title,
                                   font="bitmap14_outline", scale=TEXT_SCALE)
    else:
        y = _draw_detail_text_lines(title_lines, y, _pen_title,
                                    font="bitmap14_outline", scale=TEXT_SCALE)
    y += px(6)

    # Artists
    artist_lines = rec.get("_detail_artist_lines", None)
    if artist_lines is None:
        artist_str = rec.get("_display_artists", "")
        if not artist_str:
            artists = rec.get("artists", [])
            artist_str = display_text(", ".join(artists)) if artists else ""
        artist_lines = _wrapped_lines(artist_str, DETAIL_TEXT_W, scale=TEXT_SCALE) if artist_str else []
    if artist_lines:
        y = _draw_detail_text_lines(artist_lines, y, _pen_artist)
        y += px(4)

    return y


def _draw_detail_cover(app, rec, y):
    """Draw already-prepared cover art at the given y position."""
    # Skip if entirely outside viewport
    if y + DETAIL_COVER_SIZE <= DAY_HEADER_Y + DAY_HEADER_H:
        return
    if y >= HEIGHT:
        return

    if app.touch.dragging:
        _draw_placeholder(DETAIL_COVER_X, y,
                          DETAIL_COVER_SIZE, DETAIL_COVER_SIZE)
        return

    data = rec.get("_detail_thumb_data", None)

    if data is not None:
        draw_jpeg(data, DETAIL_COVER_X, y,
                  DETAIL_COVER_SIZE, DETAIL_COVER_SIZE)
    else:
        _draw_placeholder(DETAIL_COVER_X, y,
                          DETAIL_COVER_SIZE, DETAIL_COVER_SIZE)


def _draw_detail_info_below_cover(rec, y):
    """Draw genres, metadata line, and purchased-at below the cover."""
    # Genres
    genre_lines = rec.get("_detail_genre_lines", None)
    if genre_lines is None:
        genres = rec.get("genres", [])
        if genres:
            genre_str = display_text(", ".join(genres))
            genre_lines = _wrapped_lines(genre_str, DETAIL_TEXT_W, scale=TEXT_SCALE)
        else:
            genre_lines = []
    if genre_lines:
        y = _draw_detail_text_lines(genre_lines, y, _pen_dim_text)
        y += px(4)

    y += px(6)

    # Metadata: record_type | format | year
    meta_lines = rec.get("_detail_meta_lines", None)
    if meta_lines is None:
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
        meta_lines = _wrapped_lines(" | ".join(meta_parts), DETAIL_TEXT_W, scale=TEXT_SCALE) if meta_parts else []

    if meta_lines:
        y = _draw_detail_text_lines(meta_lines, y, _pen_dim_text)
        y += px(4)

    # Purchased at
    purchased_lines = rec.get("_detail_purchased_lines", None)
    if purchased_lines is None:
        purchased_at = rec.get("purchased_at", "")
        if purchased_at:
            purch_str = "Purchased: " + display_text(str(purchased_at)[:10])
            purchased_lines = _wrapped_lines(purch_str, DETAIL_TEXT_W, scale=TEXT_SCALE)
        else:
            purchased_lines = []
    if purchased_lines:
        y = _draw_detail_text_lines(purchased_lines, y, _pen_dim_text)

    return y


def _draw_detail_text_line(text, y, pen, font="bitmap8", scale=TEXT_SCALE):
    """Draw text centered horizontally at y, wrapping if needed.
    Returns the y-position after drawing (including wrapped lines)."""
    max_w = DETAIL_TEXT_W
    display.set_pen(pen)
    display.set_font(font)

    lines = _wrapped_lines(text, max_w, scale=scale)
    line_height = _line_height_for_font(font, scale)
    cy = y
    for line in lines:
        tw = display.measure_text(line, scale=scale)
        display.text(line, (WIDTH - tw) // 2, cy, scale=scale)
        cy += line_height

    return cy


def _draw_detail_text_lines(lines, y, pen, font="bitmap8", scale=TEXT_SCALE):
    """Draw pre-wrapped detail text centered horizontally."""
    display.set_pen(pen)
    display.set_font(font)

    line_height = _line_height_for_font(font, scale)
    cy = y
    for item in lines:
        if isinstance(item, tuple):
            line, tw = item
        else:
            line = item
            tw = display.measure_text(line, scale=scale)
        display.text(line, (WIDTH - tw) // 2, cy, scale=scale)
        cy += line_height

    return cy


def _draw_scrobble_button(app, rec, y):
    """Draw the scrobble button at (x, y). Button is horizontally centered.
    Visual state depends on app detail scrobble state."""

    bx = (WIDTH - SCROBBLE_BUTTON_W) // 2

    if app.detail.scrobble_state == "done":
        bg_pen = _pen_scrobble_done_bg
        text_pen = _pen_scrobble_done_text
        label = "Done"
    elif app.detail.scrobble_state == "loading":
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
    _draw_centered_text(label, bx, y, SCROBBLE_BUTTON_W, SCROBBLE_BUTTON_H, TEXT_H)


def _redraw_scrobble_button(app, rec):
    """Redraw and push only the visible scrobble button region."""
    if not rec.get("selected_release_id"):
        return

    if app.detail.content_height == 0:
        app.detail.content_height = _measure_detail_content(app, rec)

    button_y = _detail_scrobble_button_y(app)
    update_y = max(button_y, SCROLL_VIEWPORT_Y)
    update_bottom = min(button_y + SCROBBLE_BUTTON_H, HEIGHT)
    if update_bottom <= update_y:
        return

    bx = (WIDTH - SCROBBLE_BUTTON_W) // 2
    _set_clip_below_header()
    _draw_scrobble_button(app, rec, button_y)
    _remove_clip()
    _partial_display_update(bx, update_y, SCROBBLE_BUTTON_W,
                            update_bottom - update_y)


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


def _touch_debounce_ms(app):
    """Return the active debounce threshold for the current screen."""
    if app.screen == STATE_SEARCH_INPUT:
        return KEYBOARD_DEBOUNCE_MS
    return DEBOUNCE_MS


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


def cell_to_day(app, row, col):
    """Convert a calendar cell (row, col) to a day number (1-based)
    for the current view month. Returns None if the cell is outside
    the current month."""
    first_dow = day_of_week(app.view_year, app.view_month, 1)
    day_num = row * CELLS_PER_ROW + col - first_dow + 1
    days = days_in_month(app.view_year, app.view_month)
    if 1 <= day_num <= days:
        return day_num
    return None


def touch_to_record_index(app, y, recs=None, offset=None):
    """Map a touch y-coordinate to a record list index, accounting for
    scroll offset. Use recs/offset params for search results, or defaults
    for day view."""
    if recs is None:
        recs = app.day.records
        if offset is None:
            offset = app.day.scroll_offset
    elif offset is None:
        offset = app.search.scroll_offset

    if not recs:
        return None

    cy = RECORD_START_Y - offset
    for i, rec in enumerate(recs):
        row_h = rec.get("_row_height", THUMB_SIZE + px(8))
        if cy <= y < cy + row_h:
            return i
        cy += row_h
    return None


def _scrobble_button_hit_test(app, x, y, rec):
    """Return True if the touch (x, y) falls within the scrobble button bounds.
    Accounts for current detail scroll offset.
    Ignores touches in the fixed header area (handled separately)."""
    if not rec.get("selected_release_id"):
        return False

    # Reject touches in the fixed header zone (handled by back-button logic)
    if y <= DAY_HEADER_Y + DAY_HEADER_H:
        return False

    # Detail content height already includes the button gap and height.
    button_y = _detail_scrobble_button_y(app)
    bx = (WIDTH - SCROBBLE_BUTTON_W) // 2

    return (bx <= x <= bx + SCROBBLE_BUTTON_W and
            button_y <= y <= button_y + SCROBBLE_BUTTON_H)


# ============================================================================
# UPDATE
# ============================================================================

def update(app, msg):
    """Apply a message to the model and return effect commands."""
    tag = msg[0]

    if tag == MSG_BOOT:
        app.screen = STATE_STATUS
        app.status_message = "Music Library\nStarting up..."
        return [(FX_RENDER,), (FX_CONNECT_WIFI,)]

    if tag == MSG_WIFI_CONNECTED:
        app.api_token = msg[2]
        app.next_wifi_retry_ms = 0
        app.status_message = "Connected.\nIP: {}\nSyncing time...".format(msg[1])
        return [(FX_RENDER,), (FX_SYNC_TIME,), (FX_COLLECT_GARBAGE,)]

    if tag == MSG_WIFI_FAILED:
        app.api_token = msg[2]
        app.screen = STATE_STATUS
        app.status_message = msg[1]
        app.next_wifi_retry_ms = time.ticks_add(time.ticks_ms(), WIFI_RETRY_MS)
        return [(FX_RENDER,), (FX_COLLECT_GARBAGE,)]

    if tag == MSG_WIFI_RETRY:
        app.next_wifi_retry_ms = 0
        app.status_message = "Connecting to WiFi..."
        return [(FX_RENDER,), (FX_CONNECT_WIFI,)]

    if tag == MSG_TIME_SYNCED:
        app.today_year, app.today_month, app.today_day = msg[1], msg[2], msg[3]
        app.view_year = app.today_year
        app.view_month = app.today_month
        app.day.selected_day = app.today_day
        app.day.error = False
        app.day.scroll_offset = 0
        app.screen = STATE_HOME
        app.touch.last_activity = time.ticks_ms()
        return [(FX_RENDER,)]

    if tag == MSG_IDLE_TIMEOUT:
        if not app.touch.display_awake:
            return []
        app.touch.display_awake = False
        return [(FX_SLEEP_DISPLAY,)]

    if tag == MSG_WAKE_COMPLETE:
        app.today_year, app.today_month, app.today_day = msg[1], msg[2], msg[3]
        return [(FX_RENDER,)]

    if tag == MSG_DAY_LOADED:
        app.day.records = msg[1]
        app.day.error = msg[2]
        app.day.content_height = msg[3]
        app.day.scroll_offset = 0
        app.screen = STATE_DAY
        return [(FX_RENDER,)]

    if tag == MSG_SEARCH_LOADED:
        app.search.results = msg[1]
        app.search.error = msg[2]
        app.search.content_height = msg[3]
        app.search.scroll_offset = 0
        app.screen = STATE_SEARCH_RESULTS
        return [(FX_RENDER,)]

    if tag == MSG_DETAIL_READY:
        if app.detail.source_screen == STATE_SEARCH_RESULTS:
            app.search.results[app.detail.selected_index] = msg[2]
        else:
            app.day.records[app.detail.selected_index] = msg[2]
        app.detail.content_height = msg[1]
        app.screen = STATE_RECORD
        return [(FX_RENDER,)]

    if tag == MSG_SCROBBLED:
        app.detail.scrobble_state = "done" if msg[1] else "idle"
        return [(FX_RENDER_SCROBBLE,)]

    if tag == MSG_TOUCH_DOWN:
        return touch_down_update(app, msg[1], msg[2], msg[3])

    if tag == MSG_TOUCH_MOVE:
        return touch_move_update(app, msg[1], msg[2])

    if tag == MSG_TOUCH_UP:
        return touch_up_update(app)

    return []


def touch_down_update(app, x, y, now):
    """Start a touch gesture or consume the wake touch."""
    if not app.touch.display_awake:
        app.touch.display_awake = True
        app.touch.consume_until_release = True
        app.touch.last_activity = now
        app.touch.last_touch = now
        return [(FX_WAKE_DISPLAY,)]

    if time.ticks_diff(now, app.touch.last_touch) < _touch_debounce_ms(app):
        app.touch.consume_until_release = True
        return []

    app.touch.last_touch = now
    app.touch.last_activity = now
    app.touch.consume_until_release = False
    app.touch.gesture_screen = None

    if scrollable_screen(app.screen):
        app.touch.gesture_screen = app.screen
        app.touch.start_x = x
        app.touch.start_y = y
        app.touch.last_y = y
        app.touch.pending_delta = 0
        app.touch.dragged = False
        app.touch.redrew_drag = False
        app.touch.dragging = False
        app.touch.last_drag_redraw = now
        return []

    return tap_update(app, x, y)


def touch_move_update(app, y, now):
    """Update a scroll gesture while retaining redraw throttling."""
    if app.touch.consume_until_release or app.touch.gesture_screen is None:
        return []

    if abs(y - app.touch.start_y) >= DRAG_REDRAW_PX:
        app.touch.dragged = True

    app.touch.pending_delta += app.touch.last_y - y
    app.touch.last_y = y
    redraw_due = time.ticks_diff(now, app.touch.last_drag_redraw) >= DRAG_REDRAW_MS

    if abs(app.touch.pending_delta) < DRAG_REDRAW_PX or not redraw_due:
        return []

    changed = apply_scroll_delta(app, app.touch.gesture_screen, app.touch.pending_delta)
    app.touch.pending_delta = 0
    app.touch.last_drag_redraw = now

    if not changed:
        return []

    app.touch.dragging = True
    app.touch.redrew_drag = True
    return [(FX_RENDER_PARTIAL,)]


def touch_up_update(app):
    """Complete a gesture, issuing a tap or final scroll redraw."""
    if app.touch.consume_until_release:
        app.touch.consume_until_release = False
        app.touch.gesture_screen = None
        return []

    gesture_screen = app.touch.gesture_screen
    if gesture_screen is None:
        return []

    x, y = app.touch.start_x, app.touch.start_y
    if app.touch.dragged:
        changed = apply_scroll_delta(app, gesture_screen, app.touch.pending_delta)
        redrew_drag = app.touch.redrew_drag
        reset_gesture(app)
        if changed or redrew_drag:
            return [(FX_RENDER_PARTIAL,)]
        return []

    reset_gesture(app)
    if app.screen != gesture_screen:
        return []
    return tap_update(app, x, y)


def reset_gesture(app):
    """Clear state owned by an in-progress scroll gesture."""
    app.touch.gesture_screen = None
    app.touch.pending_delta = 0
    app.touch.dragged = False
    app.touch.redrew_drag = False
    app.touch.dragging = False


def scrollable_screen(screen):
    """Return whether a view distinguishes vertical drag from row taps."""
    return screen in (STATE_DAY, STATE_SEARCH_RESULTS, STATE_RECORD)


def scroll_offset(app, screen):
    if screen == STATE_DAY:
        return app.day.scroll_offset
    if screen == STATE_SEARCH_RESULTS:
        return app.search.scroll_offset
    return app.detail.scroll_offset


def max_scroll_offset(app, screen):
    if screen == STATE_DAY:
        return _max_scroll_offset(app)
    if screen == STATE_SEARCH_RESULTS:
        return _search_max_scroll_offset(app)
    return _max_detail_scroll_offset(app)


def set_scroll_offset(app, screen, offset):
    if screen == STATE_DAY:
        app.day.scroll_offset = offset
    elif screen == STATE_SEARCH_RESULTS:
        app.search.scroll_offset = offset
    else:
        app.detail.scroll_offset = offset


def apply_scroll_delta(app, screen, delta):
    """Clamp and apply one prepared scroll delta."""
    old_offset = scroll_offset(app, screen)
    new_offset = min(max(0, old_offset + delta), max_scroll_offset(app, screen))
    if new_offset == old_offset:
        return False
    set_scroll_offset(app, screen, new_offset)
    return True


def tap_update(app, x, y):
    """Handle one accepted tap by changing model state and returning effects."""
    if app.screen == STATE_HOME:
        return home_tap_update(app, x, y)
    if app.screen == STATE_SEARCH_INPUT:
        return search_input_tap_update(app, x, y)
    if app.screen == STATE_SEARCH_RESULTS:
        return search_results_tap_update(app, x, y)
    if app.screen == STATE_MONTH:
        return month_tap_update(app, x, y)
    if app.screen == STATE_DAY:
        return day_tap_update(app, x, y)
    if app.screen == STATE_RECORD:
        return record_tap_update(app, x, y)
    return []


def home_tap_update(app, x, y):
    if (HOME_BUTTON_X <= x <= HOME_BUTTON_X + HOME_BUTTON_W and
            HOME_BUTTON1_Y <= y <= HOME_BUTTON1_Y + HOME_BUTTON_H):
        app.search.query = ""
        app.search.keyboard_mode = "alpha"
        app.screen = STATE_SEARCH_INPUT
        return [(FX_RENDER,)]

    if (HOME_BUTTON_X <= x <= HOME_BUTTON_X + HOME_BUTTON_W and
            HOME_BUTTON2_Y <= y <= HOME_BUTTON2_Y + HOME_BUTTON_H):
        app.view_year = app.today_year
        app.view_month = app.today_month
        app.day.selected_day = app.today_day
        app.screen = STATE_MONTH
        return [(FX_RENDER,)]

    return []


def search_input_tap_update(app, x, y):
    if BACK_X <= x <= BACK_X + BACK_W and BACK_Y <= y <= BACK_Y + BACK_H:
        app.screen = STATE_HOME
        return [(FX_RENDER,)]

    action = _keyboard_hit_test(app, x, y)
    if action is None:
        return []
    if action == "toggle":
        app.search.keyboard_mode = (
            "numbers" if app.search.keyboard_mode == "alpha" else "alpha"
        )
        return [(FX_RENDER,)]
    if action == "space":
        if len(app.search.query) < 50:
            app.search.query += " "
            return [(FX_RENDER_QUERY,)]
        return []
    if action == "backspace":
        app.search.query = app.search.query[:-1]
        return [(FX_RENDER_QUERY,)]
    if action == "ok":
        if not app.search.query.strip():
            return []
        app.screen = STATE_STATUS
        app.status_message = "Searching for:\n" + app.search.query
        return [(FX_RENDER,), (FX_LOAD_SEARCH, app.search.query)]
    if len(app.search.query) < 50 and len(action) == 1:
        app.search.query += action
        return [(FX_RENDER_QUERY,)]
    return []


def search_results_tap_update(app, x, y):
    if BACK_X <= x <= BACK_X + BACK_W and BACK_Y <= y <= BACK_Y + BACK_H:
        app.screen = STATE_SEARCH_INPUT
        return [(FX_RENDER,)]
    if app.search.error:
        app.screen = STATE_STATUS
        app.status_message = "Retrying search..."
        return [(FX_RENDER,), (FX_LOAD_SEARCH, app.search.query)]
    if app.search.results:
        index = touch_to_record_index(
            app, y, recs=app.search.results, offset=app.search.scroll_offset
        )
        if index is not None:
            return open_record_update(app, STATE_SEARCH_RESULTS, index)
    return []


def month_tap_update(app, x, y):
    hx, hy = HEADER_SIDE_MARGIN, HOME_BTN_Y
    if hx <= x <= hx + HOME_BTN_W and hy <= y <= hy + HOME_BTN_H:
        app.screen = STATE_HOME
        return [(FX_RENDER,)]

    lx = HEADER_SIDE_MARGIN + HOME_BTN_W + px(4)
    if lx <= x <= lx + ARROW_W and HEADER_BUTTON_Y <= y <= HEADER_BUTTON_Y + ARROW_H:
        app.view_year, app.view_month = previous_month(app.view_year, app.view_month)
        return [(FX_RENDER,)]

    rx = WIDTH - ARROW_W - HEADER_SIDE_MARGIN
    if rx <= x <= rx + ARROW_W and HEADER_BUTTON_Y <= y <= HEADER_BUTTON_Y + ARROW_H:
        app.view_year, app.view_month = next_month(app.view_year, app.view_month)
        return [(FX_RENDER,)]

    cell = touch_to_calendar_cell(x, y)
    if cell is None:
        return []
    day_num = cell_to_day(app, cell[0], cell[1])
    if day_num is None:
        return []

    app.day.selected_day = day_num
    app.day.records = []
    app.day.error = False
    app.day.scroll_offset = 0
    app.day.content_height = 0
    app.screen = STATE_STATUS
    app.status_message = "Loading records for\n{} {}, {}...".format(
        MONTH_NAMES[app.view_month - 1], day_num, app.view_year
    )
    return [
        (FX_RENDER,),
        (FX_LOAD_DAY, app.view_year, app.view_month, day_num),
    ]


def day_tap_update(app, x, y):
    if BACK_X <= x <= BACK_X + BACK_W and BACK_Y <= y <= BACK_Y + BACK_H:
        app.screen = STATE_MONTH
        return [(FX_RENDER,)]
    if app.day.error:
        app.screen = STATE_STATUS
        app.status_message = "Retrying..."
        return [
            (FX_RENDER,),
            (FX_LOAD_DAY, app.view_year, app.view_month, app.day.selected_day),
        ]
    if app.day.records:
        index = touch_to_record_index(app, y)
        if index is not None:
            return open_record_update(app, STATE_DAY, index)
    return []


def record_tap_update(app, x, y):
    if BACK_X <= x <= BACK_X + BACK_W and BACK_Y <= y <= BACK_Y + BACK_H:
        source_screen = app.detail.source_screen
        app.detail.scroll_offset = 0
        app.detail.content_height = 0
        app.detail.scrobble_state = "idle"
        app.detail.selected_index = None
        app.detail.source_screen = None
        app.screen = STATE_SEARCH_RESULTS if source_screen == STATE_SEARCH_RESULTS else STATE_DAY
        return [(FX_RENDER,)]

    rec = selected_record(app)
    if _scrobble_button_hit_test(app, x, y, rec):
        app.detail.scrobble_state = "loading"
        return [(FX_RENDER_SCROBBLE,), (FX_SCROBBLE, rec)]
    return []


def open_record_update(app, source_screen, index):
    """Select a record and request effectful detail preparation."""
    app.detail.selected_index = index
    app.detail.source_screen = source_screen
    app.detail.scroll_offset = 0
    app.detail.content_height = 0
    app.detail.scrobble_state = "idle"
    app.screen = STATE_STATUS
    app.status_message = "Loading record..."
    return [(FX_RENDER,), (FX_PREPARE_DETAIL,)]


# ============================================================================
# EVENT WIRING AND EFFECT RUNNER
# ============================================================================

def wire_events(runtime, app):
    """Convert polling and elapsed time into application messages."""
    now = time.ticks_ms()
    messages = []

    if (app.touch.display_awake and app.touch.last_activity
            and time.ticks_diff(now, app.touch.last_activity) >= DISPLAY_SLEEP_MS):
        messages.append((MSG_IDLE_TIMEOUT,))

    if (app.next_wifi_retry_ms
            and time.ticks_diff(now, app.next_wifi_retry_ms) >= 0):
        messages.append((MSG_WIFI_RETRY,))

    point = read_touch()
    if point is None:
        if runtime.touch_down:
            runtime.touch_down = False
            messages.append((MSG_TOUCH_UP,))
    elif not runtime.touch_down:
        runtime.touch_down = True
        messages.append((MSG_TOUCH_DOWN, point[0], point[1], now))
    else:
        messages.append((MSG_TOUCH_MOVE, point[1], now))

    return messages


def dispatch(app, first_msg):
    """Process queued messages and enqueue effect results."""
    messages = [first_msg]
    index = 0

    while index < len(messages):
        commands = update(app, messages[index])
        index += 1
        for command in commands:
            follow_up = run_effect(app, command)
            if follow_up:
                messages.append(follow_up)


def run_effect(app, command):
    """Execute hardware/network commands and return any resulting message."""
    kind = command[0]

    if kind == FX_RENDER:
        render(app)
    elif kind == FX_RENDER_PARTIAL:
        render(app, partial=True)
    elif kind == FX_RENDER_QUERY:
        _redraw_search_query_field(app)
    elif kind == FX_RENDER_SCROBBLE:
        _redraw_scrobble_button(app, selected_record(app))
    elif kind == FX_CONNECT_WIFI:
        connected, detail, api_token = connect_wifi_effect(app)
        if connected:
            return MSG_WIFI_CONNECTED, detail, api_token
        return MSG_WIFI_FAILED, detail, api_token
    elif kind == FX_SYNC_TIME:
        date = sync_time_effect()
        return MSG_TIME_SYNCED, date[0], date[1], date[2]
    elif kind == FX_LOAD_DAY:
        return load_day_effect(app, command[1], command[2], command[3])
    elif kind == FX_LOAD_SEARCH:
        return load_search_effect(app, command[1])
    elif kind == FX_PREPARE_DETAIL:
        return prepare_detail_effect(app)
    elif kind == FX_SCROBBLE:
        return scrobble_effect(app, command[1])
    elif kind == FX_SLEEP_DISPLAY:
        sleep_display_effect()
    elif kind == FX_WAKE_DISPLAY:
        date = wake_display_effect(app)
        return MSG_WAKE_COMPLETE, date[0], date[1], date[2]
    elif kind == FX_COLLECT_GARBAGE:
        gc.collect()

    return None


# ============================================================================
# RENDER
# ============================================================================

def render(app, partial=False):
    """Render only the current model state; effects prepare external data."""
    if app.screen == STATE_STATUS:
        draw_status(app.status_message)
    elif app.screen == STATE_HOME:
        draw_home_screen(app)
    elif app.screen == STATE_MONTH:
        draw_month_view(app)
    elif app.screen == STATE_DAY:
        draw_day_view(app, partial=partial)
    elif app.screen == STATE_RECORD:
        draw_record_detail(app, partial=partial)
    elif app.screen == STATE_SEARCH_INPUT:
        draw_search_input(app)
    elif app.screen == STATE_SEARCH_RESULTS:
        draw_search_results(app, partial=partial)


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
    """Initialise the runtime, then continuously dispatch wired messages."""
    init_display()
    try:
        presto.set_backlight(DISPLAY_BRIGHTNESS)
    except Exception:
        pass

    app = Model()
    runtime = Runtime()
    dispatch(app, (MSG_BOOT,))

    while True:
        for msg in wire_events(runtime, app):
            dispatch(app, msg)
        time.sleep(LOOP_SLEEP_MS / 1000.0)


# ============================================================================
# STARTUP
# ============================================================================

if __name__ == "__main__":
    main()
