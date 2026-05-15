"""
Elm-style architecture proof of concept for Pimoroni Presto.

Shows WiFi status, an idle timer, and device time. Tapping the display flashes
a small red circle at the touch point.
"""

import gc
import time
import network
import ntptime

from presto import Presto


# ============================================================================
# HARDWARE
# ============================================================================

presto = Presto(full_res=True)
display = presto.display
touch = presto.touch
WIDTH, HEIGHT = display.get_bounds()


UI_SCALE = 2
TEXT_SCALE = UI_SCALE


def px(value):
    return value * UI_SCALE


# ============================================================================
# LAYOUT AND TIMING
# ============================================================================

LOOP_SLEEP_MS = 30
TICK_MS = 1_000
WIFI_CHECK_MS = 5_000
WIFI_RETRY_MS = 30_000
WIFI_CONNECT_TIMEOUT_MS = 10_000
WIFI_CONNECT_POLL_MS = 250
FLASH_MS = 180

SCREEN_PADDING = px(28)
TITLE_Y = px(28)
LABEL_X = SCREEN_PADDING
VALUE_X = px(150)
ROW_1_Y = px(90)
ROW_2_Y = px(130)
ROW_3_Y = px(170)
ROW_4_Y = px(210)
FOOTER_Y = HEIGHT - px(50)
FLASH_RADIUS = px(14)


# ============================================================================
# COLORS
# ============================================================================

BG = (24, 24, 27)
PANEL = (39, 39, 42)
TITLE = (244, 244, 245)
LABEL = (161, 161, 170)
VALUE = (228, 228, 231)
OK = (34, 197, 94)
WARN = (250, 204, 21)
ERROR = (239, 68, 68)
DIM = (113, 113, 122)
RED = (239, 68, 68)

_pen_bg = None
_pen_panel = None
_pen_title = None
_pen_label = None
_pen_value = None
_pen_ok = None
_pen_warn = None
_pen_error = None
_pen_dim = None
_pen_red = None


# ============================================================================
# MESSAGES
# ============================================================================

MSG_BOOT = 1
MSG_TICK = 2
MSG_TOUCH_DOWN = 3
MSG_TOUCH_UP = 4
MSG_FLASH_EXPIRED = 5
MSG_WIFI_CONNECTED = 6
MSG_WIFI_FAILED = 7
MSG_WIFI_STATUS = 8
MSG_TIME_SYNCED = 9


# ============================================================================
# EFFECTS
# ============================================================================

FX_RENDER = 1
FX_CONNECT_WIFI = 2
FX_CHECK_WIFI = 3
FX_SYNC_TIME = 4
FX_COLLECT_GARBAGE = 5


# ============================================================================
# MODEL
# ============================================================================

class Model:
    """Mutable application model.

    The POC keeps model updates cheap and explicit. Hardware interaction stays
    in effect functions, not in update().
    """

    def __init__(self):
        now = time.ticks_ms()
        self.now_ms = now
        self.started_ms = now
        self.last_activity_ms = now
        self.last_wifi_check_ms = 0
        self.next_wifi_retry_ms = 0

        self.wifi_status = "starting"
        self.wifi_detail = ""
        self.time_status = "not synced"
        self.current_time = format_device_time()
        self.idle_seconds = 0

        self.flash_x = None
        self.flash_y = None
        self.flash_until_ms = 0


class Runtime:
    """Runtime-only event wiring state."""

    def __init__(self):
        now = time.ticks_ms()
        self.next_tick_ms = now
        self.touch_down = False


# ============================================================================
# UPDATE
# ============================================================================

def update(model, msg):
    """Apply a message to the model and return effect commands."""
    tag = msg[0]

    if tag == MSG_BOOT:
        model.wifi_status = "connecting"
        model.wifi_detail = "Looking for secrets.py"
        model.time_status = "waiting for WiFi"
        model.current_time = format_device_time()
        return [
            (FX_RENDER,),
            (FX_CONNECT_WIFI,),
        ]

    if tag == MSG_TICK:
        now = msg[1]
        model.now_ms = now
        model.current_time = format_device_time()
        model.idle_seconds = time.ticks_diff(now, model.last_activity_ms) // 1000

        commands = [(FX_RENDER,)]

        if should_retry_wifi(model, now):
            model.wifi_status = "connecting"
            model.wifi_detail = "Retrying"
            commands.append((FX_RENDER,))
            commands.append((FX_CONNECT_WIFI,))
            return commands

        if time.ticks_diff(now, model.last_wifi_check_ms) >= WIFI_CHECK_MS:
            model.last_wifi_check_ms = now
            commands.append((FX_CHECK_WIFI,))

        return commands

    if tag == MSG_TOUCH_DOWN:
        x, y, now = msg[1], msg[2], msg[3]
        model.now_ms = now
        model.last_activity_ms = now
        model.idle_seconds = 0
        model.flash_x = x
        model.flash_y = y
        model.flash_until_ms = time.ticks_add(now, FLASH_MS)
        return [(FX_RENDER,)]

    if tag == MSG_TOUCH_UP:
        return []

    if tag == MSG_FLASH_EXPIRED:
        model.flash_x = None
        model.flash_y = None
        model.flash_until_ms = 0
        return [(FX_RENDER,)]

    if tag == MSG_WIFI_CONNECTED:
        ip = msg[1]
        now = time.ticks_ms()
        model.wifi_status = "connected"
        model.wifi_detail = ip
        model.last_wifi_check_ms = now
        model.next_wifi_retry_ms = 0
        model.time_status = "syncing"
        return [
            (FX_RENDER,),
            (FX_SYNC_TIME,),
            (FX_COLLECT_GARBAGE,),
        ]

    if tag == MSG_WIFI_FAILED:
        reason = msg[1]
        now = time.ticks_ms()
        model.wifi_status = "failed"
        model.wifi_detail = reason
        model.last_wifi_check_ms = now
        model.next_wifi_retry_ms = time.ticks_add(now, WIFI_RETRY_MS)
        model.time_status = "not synced"
        return [
            (FX_RENDER,),
            (FX_COLLECT_GARBAGE,),
        ]

    if tag == MSG_WIFI_STATUS:
        connected, ip = msg[1], msg[2]
        if connected:
            model.wifi_status = "connected"
            model.wifi_detail = ip
            model.next_wifi_retry_ms = 0
        elif model.wifi_status == "connected":
            model.wifi_status = "disconnected"
            model.wifi_detail = "Will retry"
            model.next_wifi_retry_ms = time.ticks_add(time.ticks_ms(), WIFI_RETRY_MS)
        return [(FX_RENDER,)]

    if tag == MSG_TIME_SYNCED:
        ok = msg[1]
        model.current_time = format_device_time()
        model.time_status = "synced" if ok else "sync failed"
        return [(FX_RENDER,)]

    return []


def should_retry_wifi(model, now):
    if model.wifi_status == "connected" or model.wifi_status == "connecting":
        return False
    if model.next_wifi_retry_ms == 0:
        return False
    return time.ticks_diff(now, model.next_wifi_retry_ms) >= 0


# ============================================================================
# EVENT WIRING
# ============================================================================

def wire_events(runtime, model):
    """Convert hardware polling and time into app messages."""
    now = time.ticks_ms()
    messages = []

    if time.ticks_diff(now, runtime.next_tick_ms) >= 0:
        runtime.next_tick_ms = time.ticks_add(now, TICK_MS)
        messages.append((MSG_TICK, now))

    point = read_touch()
    if point is None:
        if runtime.touch_down:
            runtime.touch_down = False
            messages.append((MSG_TOUCH_UP, now))
    elif not runtime.touch_down:
        runtime.touch_down = True
        messages.append((MSG_TOUCH_DOWN, point[0], point[1], now))

    if model.flash_until_ms and time.ticks_diff(now, model.flash_until_ms) >= 0:
        messages.append((MSG_FLASH_EXPIRED,))

    return messages


# ============================================================================
# EFFECT RUNNER
# ============================================================================

def dispatch(model, first_msg):
    """Process messages, run returned effects, and enqueue follow-up messages."""
    messages = [first_msg]
    index = 0

    while index < len(messages):
        msg = messages[index]
        index += 1

        commands = update(model, msg)
        for command in commands:
            follow_up = run_effect(model, command)
            if follow_up:
                messages.extend(follow_up)


def run_effect(model, command):
    kind = command[0]

    if kind == FX_RENDER:
        render(model)
        return []

    if kind == FX_CONNECT_WIFI:
        return [connect_wifi_effect()]

    if kind == FX_CHECK_WIFI:
        return [check_wifi_effect()]

    if kind == FX_SYNC_TIME:
        return [sync_time_effect()]

    if kind == FX_COLLECT_GARBAGE:
        gc.collect()
        return []

    return []


def connect_wifi_effect():
    try:
        import secrets
    except ImportError:
        return (MSG_WIFI_FAILED, "secrets.py missing")

    ssid = getattr(secrets, "WIFI_SSID", "")
    password = getattr(secrets, "WIFI_PASSWORD", "")

    if not ssid:
        return (MSG_WIFI_FAILED, "WIFI_SSID missing")

    try:
        wlan = network.WLAN(network.STA_IF)
        wlan.active(True)

        if wlan.isconnected():
            return (MSG_WIFI_CONNECTED, wlan.ifconfig()[0])

        wlan.connect(ssid, password)
        start = time.ticks_ms()

        while not wlan.isconnected():
            if time.ticks_diff(time.ticks_ms(), start) >= WIFI_CONNECT_TIMEOUT_MS:
                return (MSG_WIFI_FAILED, "connect timeout")
            sleep_ms(WIFI_CONNECT_POLL_MS)

        return (MSG_WIFI_CONNECTED, wlan.ifconfig()[0])
    except Exception:
        return (MSG_WIFI_FAILED, "connect error")


def check_wifi_effect():
    try:
        wlan = network.WLAN(network.STA_IF)
        wlan.active(True)
        if wlan.isconnected():
            return (MSG_WIFI_STATUS, True, wlan.ifconfig()[0])
        return (MSG_WIFI_STATUS, False, "")
    except Exception:
        return (MSG_WIFI_STATUS, False, "")


def sync_time_effect():
    try:
        ntptime.settime()
        return (MSG_TIME_SYNCED, True)
    except Exception:
        return (MSG_TIME_SYNCED, False)


# ============================================================================
# RENDER
# ============================================================================

def render(model):
    """Imperative renderer. Drawing and display update are intentional effects."""
    display.set_pen(_pen_bg)
    display.clear()

    draw_header()
    draw_status_rows(model)
    draw_flash(model)
    draw_footer()

    presto.update()


def draw_header():
    display.set_pen(_pen_title)
    display.set_font("bitmap14_outline")
    text = "Elm-style Presto POC"
    draw_centered_text(text, TITLE_Y, scale=TEXT_SCALE)


def draw_status_rows(model):
    draw_row("WiFi", wifi_status_text(model), ROW_1_Y, wifi_pen(model))
    draw_row("Detail", model.wifi_detail or "-", ROW_2_Y, _pen_value)
    draw_row("Idle", format_idle(model.idle_seconds), ROW_3_Y, _pen_value)
    draw_row("Time", model.current_time + "  " + model.time_status, ROW_4_Y, _pen_value)


def draw_row(label, value, y, value_pen):
    display.set_pen(_pen_panel)
    display.rectangle(SCREEN_PADDING, y - px(12), WIDTH - 2 * SCREEN_PADDING, px(22))

    display.set_font("bitmap8")
    display.set_pen(_pen_label)
    display.text(label, LABEL_X, y, scale=TEXT_SCALE)

    display.set_pen(value_pen)
    display.text(value, VALUE_X, y, scale=TEXT_SCALE)


def draw_flash(model):
    if model.flash_x is None or model.flash_y is None:
        return

    display.set_pen(_pen_red)
    try:
        display.circle(model.flash_x, model.flash_y, FLASH_RADIUS)
    except Exception:
        display.rectangle(
            model.flash_x - FLASH_RADIUS,
            model.flash_y - FLASH_RADIUS,
            FLASH_RADIUS * 2,
            FLASH_RADIUS * 2
        )


def draw_footer():
    display.set_pen(_pen_dim)
    display.set_font("bitmap8")
    draw_centered_text("Tap anywhere", FOOTER_Y, scale=TEXT_SCALE)


def draw_centered_text(text, y, scale=TEXT_SCALE):
    width = display.measure_text(text, scale=scale)
    display.text(text, (WIDTH - width) // 2, y, scale=scale)


def wifi_status_text(model):
    if model.wifi_status == "connected":
        return "Connected"
    if model.wifi_status == "connecting":
        return "Connecting"
    if model.wifi_status == "disconnected":
        return "Disconnected"
    if model.wifi_status == "failed":
        return "Failed"
    return "Starting"


def wifi_pen(model):
    if model.wifi_status == "connected":
        return _pen_ok
    if model.wifi_status == "connecting":
        return _pen_warn
    return _pen_error


# ============================================================================
# HARDWARE HELPERS
# ============================================================================

def init_display():
    global _pen_bg, _pen_panel, _pen_title, _pen_label, _pen_value
    global _pen_ok, _pen_warn, _pen_error, _pen_dim, _pen_red

    _pen_bg = display.create_pen(*BG)
    _pen_panel = display.create_pen(*PANEL)
    _pen_title = display.create_pen(*TITLE)
    _pen_label = display.create_pen(*LABEL)
    _pen_value = display.create_pen(*VALUE)
    _pen_ok = display.create_pen(*OK)
    _pen_warn = display.create_pen(*WARN)
    _pen_error = display.create_pen(*ERROR)
    _pen_dim = display.create_pen(*DIM)
    _pen_red = display.create_pen(*RED)

    try:
        display.set_font("bitmap8")
    except Exception:
        pass

    try:
        presto.set_backlight(1.0)
    except Exception:
        pass


def read_touch():
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

        normalised = normalise_touch(point)
        if normalised is not None:
            return normalised

    return None


def normalise_touch(point):
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


# ============================================================================
# FORMAT HELPERS
# ============================================================================

def format_device_time():
    lt = time.localtime()
    return "{:02d}:{:02d}:{:02d}".format(lt[3], lt[4], lt[5])


def format_idle(seconds):
    minutes = seconds // 60
    remaining = seconds % 60
    return "{:02d}:{:02d}".format(minutes, remaining)


def sleep_ms(ms):
    try:
        time.sleep_ms(ms)
    except AttributeError:
        time.sleep(ms / 1000.0)


# ============================================================================
# MAIN
# ============================================================================

def main():
    init_display()
    model = Model()
    runtime = Runtime()

    dispatch(model, (MSG_BOOT,))

    while True:
        messages = wire_events(runtime, model)
        for msg in messages:
            dispatch(model, msg)
        sleep_ms(LOOP_SLEEP_MS)


main()
