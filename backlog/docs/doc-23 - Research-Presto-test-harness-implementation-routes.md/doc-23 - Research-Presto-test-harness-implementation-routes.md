---
id: doc-23
title: "Research: Presto test harness implementation routes"
type: specification
created_date: "2026-05-15 07:22"
tags:
  - presto
  - testing
  - micropython
  - research
---

# Research: Presto test harness implementation routes

Status: **Awaiting feedback** — 3 routes presented below.

## Current state

- `presto/main.py` is a 2717-line monolithic MicroPython app for the Pimoroni Presto (480×480 touch display).
- Hardware init happens at module level: `presto = Presto(full_res=True)` creates the display, touch, and WiFi objects on import.
- `main()` runs an infinite `while True` event loop with touch dispatch, display sleep, and WiFi management.
- `main()` is called unconditionally at the bottom of the file — importing the module always starts the app.
- `pimoroni-emulator` v0.5.0 is already configured in `presto/mise.toml` with an `emulator` task.
- The emulator's `DeviceTest` class provides: headless display, `run_frames()`, `touch()`, `click_button()`, `screenshot()`, `assert_display_matches()`.
- The emulator installs mock modules for `presto`, `picographics`, `network`, `jpegdec`, etc. before running the app, so hardware calls work in the test environment.

## Key challenge

The current `main.py` architecture couples three concerns at module level:

1. **Hardware initialization** — creates Presto/display/touch on import
2. **State + rendering** — all functions are module-level, operating on globals
3. **Event loop** — `main()` is called unconditionally at the bottom

For a test harness to work, we need to decouple at least #3 so that the event loop doesn't run when we import the module for testing. The emulator's mock system handles #1 (hardware mocks), and the rendering functions (#2) are already callable once imported.

---

## Route A: Minimal guard — add testing flag to main.py

**Approach:** Add a single `if __name__ == "__main__":` guard (or environment-variable check) around the `main()` call at the bottom of `main.py`. Tests import the module as a library, set up app state, and call render functions directly. The emulator's `DeviceTest` provides the headless display.

### What changes in main.py

```python
# Bottom of main.py — only change needed:
if __name__ == "__main__":
    main()
```

When the emulator's `DeviceTest.setUp()` runs the app via `runpy.run_path()`, `__name__` is set to `"__main__"`, so the guard would NOT prevent `main()` from running. We need an alternative signal.

**Better guard:** Use an environment variable:

```python
# Bottom of main.py:
import os
if os.environ.get("PRESTO_TEST_MODE") != "1":
    main()
```

This works because the emulator runs on CPython where `os.environ` is available. The test harness sets `PRESTO_TEST_MODE=1` before importing.

### Test structure

```
presto/
  tests/
    __init__.py
    conftest.py          # Sets PRESTO_TEST_MODE=1, imports main, sets up emulator
    test_screens.py      # Smoke tests: render each screen, capture screenshot
    test_touch.py        # Touch interaction tests
    fixtures/            # Reference screenshots for visual regression
```

### Example test

```python
import os
os.environ["PRESTO_TEST_MODE"] = "1"

from emulator.testing import DeviceTest
import main  # imports app module without running main()

class TestScreens(DeviceTest):
    device = "presto"

    def test_home_screen(self):
        app = main.AppState()
        main.init_display()
        main.draw_home_screen(app)
        self.assert_display_matches("fixtures/home_screen.png")
```

### Pros

- **Smallest change to main.py** — one guard at the bottom, zero structural changes.
- **Tests actual render code** — calls the exact same functions that run on the device.
- **Fast** — no WiFi/NTP wait, no touch simulation delays.
- **Easy to extend** — each new test is just: set up state → call render → screenshot.
- **CI-ready** — headless execution works in any Python 3 environment with `pimoroni-emulator` pip installed.

### Cons

- Testing concern leaks into app code (the guard).
- `main.py` remains monolithic — doesn't force better architecture.
- All module-level globals still exist on import; state isolation between tests requires care.

---

## Route B: Extract rendering and state into separate modules

**Approach:** Refactor `main.py` into a package structure. Rendering functions move to `presto/lib/display.py`, state classes move to `presto/lib/state.py`, API/networking stays in `presto/lib/api.py`. `main.py` becomes a thin entry point. Tests import from `lib/*` modules directly.

### Package structure

```
presto/
  main.py               # Thin entry point: init hardware, run event loop
  lib/
    __init__.py
    state.py            # AppState, DayListState, SearchState, DetailState, TouchState
    display.py          # All draw_* functions, pen init, helpers
    api.py              # fetch_records, fetch_search_results, fetch_thumbnail
    network.py          # connect_wifi, sync_time, wifi_connected
    config.py           # Layout constants, colors, timing
    layout.py           # px(), text helpers, wrapping
  tests/
    __init__.py
    conftest.py
    test_screens.py
    test_state.py
    fixtures/
```

### What changes in main.py

`main.py` shrinks to ~50 lines:

```python
"""Presto Music Library — application entry point."""
from presto import Presto
from lib.state import AppState
from lib.display import init_display, draw_home_screen, draw_status, ...
from lib.network import connect_wifi, sync_time, set_today
from lib.api import ...

# Hardware init
presto = Presto(full_res=True)
display = presto.display
touch = presto.touch
WIDTH, HEIGHT = display.get_bounds()

def main():
    # ... event loop using imported functions ...

main()
```

### Test structure (same as Route A but cleaner)

```python
from lib.state import AppState
from lib.display import init_display, draw_home_screen, draw_month_view

def test_home_screen():
    app = AppState()
    init_display()
    draw_home_screen(app)
    # ...
```

### Pros

- **Clean separation** — rendering, state, and I/O are in distinct modules.
- **No test code in production files** — no guard needed.
- **Enables unit testing** — can test state transitions, text wrapping, layout math without the emulator.
- **Reusable** — `lib/display.py` could be shared with other Presto apps.
- **Aligns with project conventions** — matches the Elixir-side pattern of separating contexts, schemas, and workers.

### Cons

- **Large diff** — touches every function in main.py (moving import paths, updating globals).
- **Risk of regressions** — moving 2717 lines of code across files can introduce subtle bugs.
- **Must test on physical device after refactoring** — cannot rely on emulator alone.
- **Module-level globals are tricky** — `display`, `_pen_bg`, etc. need to be accessible from `lib/display.py` but initialized by hardware code.

---

## Route C: End-to-end emulator tests with touch simulation (no code changes)

**Approach:** Write `DeviceTest` subclasses that run `main.py` as-is in the emulator. Use touch simulation and frame waiting to navigate through the app. Capture screenshots at each state.

### Test structure

```python
from emulator.testing import DeviceTest

class TestScreensE2E(DeviceTest):
    device = "presto"
    app = "main.py"  # Runs the full app

    def test_can_reach_home_screen(self):
        self.run_frames(30)  # Wait for boot, WiFi fail, status screens
        self.screenshot("home_screen.png")

    def test_can_navigate_to_month_view(self):
        self.run_frames(30)
        # Tap "Today's Records" button (coordinates from layout constants)
        self.touch(240, 195)  # HOME_BUTTON2_Y center
        self.run_frames(10)
        self.screenshot("month_view.png")
```

### Pros

- **Zero code changes** — `main.py` stays exactly as-is.
- **Tests the full app** — WiFi, NTP, API calls all run (or fail) as they would on device.
- **Catches integration bugs** — if a refactoring breaks the event loop, these tests catch it.

### Cons

- **WiFi blocks** — `connect_wifi()` will try to connect and fail (timeout: 30 seconds). Need `--no-wifi` or mock the network module.
- **NTP blocks** — `sync_time()` calls `ntptime.settime()` which tries to reach an NTP server.
- **API calls fail** — all `urequests` calls will get connection errors.
- **Fragile timing** — `run_frames(30)` is guesswork; the app may be in an unexpected state.
- **Slow** — each test takes seconds to minutes due to boot sequence and timeouts.
- **Hard to test specific states** — reaching deep states requires complex touch sequences.
- **No isolation** — tests share emulator state; ordering matters.

### Workarounds for Route C

- Create mock `secrets.py` on the test path with dummy credentials (WiFi will still fail but won't crash).
- Monkey-patch `network.WLAN` to return "connected" before tests run.
- Use `--no-wifi` CLI flag (but this isn't exposed through `DeviceTest` — would need to set `_emulator_state` directly).
- These workarounds add complexity and move us toward Route A/B anyway.

---

## Recommendation

**Route A (minimal guard) is the recommended starting point** because:

1. It gets us rendering smoke tests with the smallest possible change to `main.py` (2 lines).
2. It validates that all screens render without crashing — the stated minimum requirement.
3. It's fast to implement (a few hours) and easy to extend later.
4. It can evolve into Route B later — the test files written for Route A still work after refactoring.

If the team prefers to invest in architecture now, **Route B** is the better long-term solution and aligns with the project's Elixir-side conventions of separating concerns into modules. It just carries more implementation risk.

**Route C** is not recommended as a starting point. It adds complexity without proportional benefit. It could be valuable later as a complement to Route A/B for testing the full boot sequence and touch-driven navigation, but only after the blocking network calls are addressed.

---

## Open questions for feedback

1. **Route A or B?** Minimal guard (2-line change) or full extraction into `lib/` modules?
2. **What to test first?** Smoke-test all screens, or focus on specific views (month, day, detail)?
3. **Visual regression or crash-only?** Should screenshots be compared against reference images (`assert_display_matches`), or is "renders without exception" sufficient for now?
4. **CI integration?** Should the tests run in CI? The `pimoroni-emulator` dependency needs to be installed in CI — is that acceptable?
5. **secrets.py in tests?** The app reads credentials from `secrets.py`. For tests, should we create a test `secrets.py` with dummy values, or refactor to make credentials injectable?
