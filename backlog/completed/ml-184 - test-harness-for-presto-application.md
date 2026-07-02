---
id: ML-184
title: test harness for presto application
status: Done
assignee:
  - pi
created_date: "2026-05-15 07:18"
updated_date: "2026-05-15 09:48"
labels:
  - presto
  - ready
dependencies: []
references:
  - "https://github.com/iksaif/pimoroni-emu/blob/main/README.md#testing"
  - presto/mise.toml
  - presto/main.py
  - doc-23 - Research-Presto-test-harness-implementation-routes.md
modified_files:
  - presto/main.py
  - presto/mise.toml
  - presto/tests/__init__.py
  - presto/tests/conftest.py
  - presto/tests/test_screens.py
  - presto/README.md
  - presto/AGENTS.md
priority: medium
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->

Build a test harness for the Presto application so that it's possible at the very minimum to render screens and check them. The pimoroni-emulator dependency is already configured in presto/mise.toml and provides a DeviceTest testing framework with headless execution, screenshot capture, button simulation, and touch input. Reference: https://github.com/iksaif/pimoroni-emu/blob/main/README.md#testing

<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria

<!-- AC:BEGIN -->

- [x] #1 main.py can be imported without starting the event loop when PRESTO_TEST_MODE=1 is set
- [ ] #2 Deploying to physical Presto still works (mise run presto)
- [x] #3 mise run emulator still opens the emulator window
- [x] #4 All 7 smoke tests pass (home, month, day-empty, day-error, record-detail, search-input, search-results)
- [x] #5 mise run test executes all tests and reports results
- [x] #6 presto/README.md includes a Testing section with usage instructions
- [x] #7 presto/AGENTS.md mentions the test harness

<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->

## Implementation Plan: Route A — Minimal guard + emulator smoke tests

### 1. Objective alignment

The goal is a test harness that can, at minimum, render each Presto screen and verify it doesn't crash. Route A achieves this by:

1. Adding a single guard around the `main()` call so the module can be imported without starting the event loop.
2. Writing `DeviceTest`-based tests that import the app module, set up `AppState`, call render functions, and capture screenshots.
3. Configuring a `mise` task (`presto.test`) so tests are runnable with one command.

This directly maps: **problem** = no way to verify screens render correctly without deploying to physical hardware → **solution** = importable module + emulator-based smoke tests.

### 2. Simplicity and alternatives considered

**Chosen: Route A (minimal guard).** The only change to `main.py` is wrapping `main()` in an environment-variable guard. The test harness lives entirely in new files under `presto/tests/`.

**No test `secrets.py` is needed** — `secrets` is imported lazily inside `connect_wifi()` (line 516), not at module level. As long as the guard prevents `main()` from running, `connect_wifi()` is never called and the import never happens. The module-level `from presto import Presto` and `Presto(full_res=True)` call are handled by the emulator's mock system.

**Alternatives evaluated and deferred:**

- **Route B (extract lib/ modules):** Cleaner architecture but a 2717-line refactoring with regression risk. Deferred — can be done later as a follow-up, and all tests written for Route A will still pass.
- **Route C (full E2E with touch simulation):** Zero code changes but blocked by WiFi/NTP timeouts (30s each), fragile frame timing, and complex touch sequences. Not viable as a starting point.

**Justification:** Route A is the simplest change that achieves the stated minimum ("render screens and check them") with the least risk. It amortizes into Route B if desired.

**Decision on visual regression:** Smoke tests for this task will verify "renders without exception" only — no `assert_display_matches` with reference fixtures. Screenshots are saved for manual inspection. Reference-based visual regression can be added in a follow-up task once the harness is stable and a baseline is established.

### 3. Completeness and sequencing

#### Step 1: Add test-mode guard to main.py

- Add `import os` at the top of imports (after `import gc` on line 31).
- Replace the bare `main()` call at the bottom (line 2716) with:
  ```python
  if os.environ.get("PRESTO_TEST_MODE") != "1":
      main()
  ```
- Verify the app still deploys and runs on the physical Presto: `mise run presto`.
- Verify the emulator task still works: `cd presto && mise run emulator`.

**Verification:** Deploy to physical device and confirm the app boots normally. Run `mise run emulator` and confirm the emulator window opens with the splash screen. Confirm `PRESTO_TEST_MODE=1` is NOT set in normal `mise run emulator` (it should not be).

#### Step 2: Create test infrastructure

- Create `presto/tests/` directory.
- Create `presto/tests/__init__.py` (empty).
- Create `presto/tests/conftest.py`:
  - Set `os.environ["PRESTO_TEST_MODE"] = "1"` before importing `main`.
  - `import main` — this imports the app module without starting the event loop.
  - Provide a pytest fixture that calls `main.init_display()` once per test class (pen creation depends on `display` which is set up at module level by the emulator mock).
  - Provide a helper `make_mock_record()` that returns a dict with all required fields and cache keys pre-set so no draw function attempts a network call (see Step 3 for the exact shape).
  - Monkey-patch `main.fetch_thumbnail` to raise `RuntimeError("Network call in smoke test")` so any accidental network access is caught immediately.
- Create `presto/tests/fixtures/` directory for saved screenshots (not reference images — used for manual inspection).

**Verification:** `cd presto && PRESTO_TEST_MODE=1 python3 -c "import main; print('Import OK, AppState:', main.AppState)"` succeeds without starting the event loop and without importing `secrets`.

#### Step 3: Write smoke tests for all 7 screens

Create `presto/tests/test_screens.py` with one test per screen. Every test follows the pattern: `init_display()`, create `AppState()`, set state fields, call draw function, assert no exception, optionally save screenshot.

**Mock record shape** — records passed to draw functions must include ALL of these keys to avoid triggering thumbnail fetches, text re-measurement, or attribute errors:

```python
{
    "id": "rec-1",
    "selected_release_id": "release-uuid-1",
    "title": "Kind of Blue",
    "artists": ["Miles Davis"],
    "format": "Vinyl",
    "release_date": "1959-08-17",
    "genres": ["Jazz", "Modal"],
    "record_type": "LP",
    "purchased_at": "2024-03-15",

    # Pre-computed display strings (set by prepare_record_list / _measure_detail_content)
    "_display_title": "Kind of Blue",
    "_display_artists": "Miles Davis",
    "_display_meta": "Vinyl | 1959",
    "_display_title_lines": [("Kind of Blue", 120)],
    "_display_artist_lines": [("Miles Davis", 120)],
    "_display_meta_lines": [("Vinyl | 1959", 120)],

    # Thumbnail cache keys — set to None so draw functions use placeholders
    "_thumb_url": "",
    "_thumb_data": None,
    "_thumb_failed": True,

    # Detail-view cache keys
    "_detail_thumb_data": None,
    "_detail_thumb_failed": True,
    "_detail_title_lines": [("Kind of Blue", 22)],
    "_detail_artist_lines": [("Miles Davis", 15)],
    "_detail_genre_lines": [("Jazz, Modal", 15)],
    "_detail_meta_lines": [("LP | Vinyl | 1959", 15)],
    "_detail_purchased_lines": [("Purchased: 2024-03-15", 15)],

    # Row height (computed by prepare_record_list)
    "_row_height": 88,
}
```

The conftest.py `make_mock_record()` helper constructs this dict so individual tests don't repeat it.

**Individual tests:**

1. **test_home_screen_renders** — `init_display()`, create `AppState()`, call `draw_home_screen(app)`, assert no exception, take screenshot.
2. **test_month_view_renders** — set `app.screen = STATE_MONTH`, `app.view_year = 2026`, `app.view_month = 5`, call `draw_month_view(app)`, screenshot.
3. **test_day_view_empty_renders** — set `app.screen = STATE_DAY`, `app.day.records = []`, `app.day.error = False`, `app.view_year = 2026`, `app.view_month = 5`, `app.day.selected_day = 15`, call `draw_day_view(app)`, screenshot.
4. **test_day_view_error_renders** — set `app.day.error = True` (records can be anything), call `draw_day_view(app)`, screenshot.
5. **test_record_detail_renders** — set `app.screen = STATE_RECORD`, populate `app.day.records` with one mock record, set `app.detail.selected_index = 0`, `app.detail.source_screen = STATE_DAY` (required by `draw_record_detail`), call `draw_record_detail(app)`, screenshot.
6. **test_search_input_renders** — set `app.screen = STATE_SEARCH_INPUT`, call `draw_search_input(app)`, screenshot.
7. **test_search_results_renders** — set `app.screen = STATE_SEARCH_RESULTS`, populate `app.search.results` with mock records, pre-compute `app.search.content_height` (or call `prepare_record_list` which won't trigger network calls because `_thumb_failed=True` and `_thumb_data=None`), call `draw_search_results(app)`, screenshot.

**Verification:** All 7 tests pass with `pytest presto/tests/ -v`. The `fetch_thumbnail` monkey-patch confirms no network calls were attempted. Manually inspect generated screenshots to confirm they look correct (no blank screens, text is visible, layouts are intact).

#### Step 4: Configure mise task for testing

- Add a `[tasks.test]` section to `presto/mise.toml`:
  ```toml
  [tasks.test]
  run = "pytest tests/ -v"
  dir = "{{cwd}}"
  ```
- Test it: `cd presto && mise run test`.

**Verification:** `mise run test` runs all tests and reports results with the standard pytest summary (7 passed).

#### Step 5: Documentation

- Update `presto/README.md` with a "Testing" section explaining:
  - Prerequisites: `pimoroni-emulator` (already installed via `mise`), Python 3, `pytest`.
  - How to run tests: `mise run test` (in `presto/` directory) or `cd presto && mise run test`.
  - What the tests cover: smoke tests for each screen (home, month, day-empty, day-error, record-detail, search-input, search-results).
  - How to add new tests: create a test function in `presto/tests/test_screens.py` following the existing pattern (init display, set up state, call draw function, assert no crash).
  - That tests use mock data and do not make network requests.
  - That screenshots are saved to `presto/tests/fixtures/` for manual inspection.
- Update `presto/AGENTS.md`:
  - Add a new section `## Testing` after the "Deployment And Verification" section:

    ```markdown
    ## Testing

    The test harness lives in `presto/tests/` and uses the `pimoroni-emulator`'s
    `DeviceTest` framework for headless smoke testing.

    - Run tests: `mise run test`
    - Tests import `main.py` without starting the event loop (guarded by `PRESTO_TEST_MODE=1`).
    - Smoke tests cover every screen state. When adding a new screen, add a corresponding test in `test_screens.py`.
    - All tests use mock data. No network calls are made during test execution.
    - Screenshots are saved to `presto/tests/fixtures/` for manual visual inspection.
    ```

### 4. Verifiability

Each step has explicit verification:

| Step              | Verification                                                                                                                              |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| 1. Guard          | Deploy to physical Presto, app boots normally. `mise run emulator` opens window. `PRESTO_TEST_MODE` is not set in normal emulator runs.   |
| 2. Infrastructure | `PRESTO_TEST_MODE=1 python3 -c "import main; print(main.AppState)"` succeeds without event loop. No `secrets` import occurs.              |
| 3. Smoke tests    | `pytest presto/tests/ -v` — all 7 tests pass. `fetch_thumbnail` monkey-patch confirms zero network calls. Screenshots visually inspected. |
| 4. Mise task      | `cd presto && mise run test` runs all tests and reports 7 passed.                                                                         |
| 5. Docs           | README has "Testing" section. AGENTS.md has "Testing" section with conventions.                                                           |

### 5. Architecture impact analysis

| Touchpoint             | Impact                                                                                                                                                                                   |
| ---------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `presto/main.py`       | **Minimal:** `import os` added to imports (line 31); `main()` call (line 2716) wrapped in `os.environ` guard. No function signatures, globals, layout constants, or other logic changes. |
| `presto/mise.toml`     | **Addition:** new `[tasks.test]` task. Existing `emulator` and `presto` tasks unchanged.                                                                                                 |
| `presto/tests/`        | **New directory:** `__init__.py`, `conftest.py`, `test_screens.py`, `fixtures/`. No impact on existing code.                                                                             |
| `presto/README.md`     | **Addition:** "Testing" section.                                                                                                                                                         |
| `presto/AGENTS.md`     | **Addition:** "Testing" section with conventions.                                                                                                                                        |
| Physical Presto device | **No impact.** The guard is a no-op when `PRESTO_TEST_MODE` is unset (normal operation).                                                                                                 |
| Emulator               | **No impact.** The `emulator` task runs `main.py` normally; the env var is not set.                                                                                                      |

**No migration or deprecation needed.** All changes are additive except the `main()` guard.

### 6. Performance profile

- **Test execution time:** Each smoke test renders one screen and optionally saves a PNG screenshot. Screen rendering is fast (tens of ms in the headless emulator) but the dominant cost is `DeviceTest.setUp()` emulator startup (~500ms-1s per test class). All 7 tests in a single class should complete in under 5 seconds. If each test gets its own class (worst case), total time could be ~7-10 seconds.
- **Database queries:** None — tests use mock data and don't hit any API or database.
- **N+1 risks:** None — no database or API calls in smoke tests. The `fetch_thumbnail` monkey-patch guarantees this.
- **Memory footprint:** The emulator's headless display holds a single 480×480 framebuffer (~900KB uncompressed). Negligible for test environments.
- **No latency/throughput concerns** — tests are offline and single-threaded.

### 7. Benchmarking requirements

No ongoing benchmarks are needed for this change. The test harness itself is the verification mechanism.

**One-off validation:** After smoke tests pass, run `time pytest presto/tests/ -v` to record baseline execution time. If future changes cause tests to slow down significantly (>5x), investigate.

### 8. Cost profile

**Zero cost.** All testing uses:

- `pimoroni-emulator` (free, open-source, MIT licensed)
- Local headless rendering (no API calls, no cloud resources)
- Mock data in tests (no network requests)

No paid resources are consumed during test execution.

### 9. Production infrastructure steps

**No production changes required.** The test harness runs entirely locally and does not affect:

- The deployed Phoenix application
- The physical Presto device
- API endpoints or databases
- Coolify, Litestream, or any production service

The only "deployment" consideration is that `main.py` continues to work on the physical Presto after the guard is added — verified in Step 1.

### 10. Documentation updates

| File                          | Change                                                                                                                                                          |
| ----------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `presto/README.md`            | Add "Testing" section: prerequisites, how to run, what's covered, how to add tests, mock data note, screenshot location.                                        |
| `presto/AGENTS.md`            | Add `## Testing` section after "Deployment And Verification": how to run tests, architecture (guard + DeviceTest), smoke test conventions, mock data guarantee. |
| `docs/architecture.md`        | No changes needed — Presto is not covered in the main architecture doc (it's a separate MicroPython app).                                                       |
| `docs/project-conventions.md` | No changes needed — existing testing conventions cover Elixir only.                                                                                             |

<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->

## Implementation notes

### Step 1: Guard

- Added `import os` after `import gc` in main.py
- Wrapped bare `main()` call with `if os.environ.get("PRESTO_TEST_MODE") != "1":`
- Emulator still launches: `mise run emulator` opens normally

### Step 2: Infrastructure

- Created `presto/tests/__init__.py`, `conftest.py`, `test_screens.py`, `fixtures/`
- conftest sets `PRESTO_TEST_MODE=1`, provides session-scoped `_emulator` fixture
  (installs mocks + headless display), `main_module` fixture (imports main lazily),
  `init_display` fixture, and `make_mock_record()` helper
- `fetch_thumbnail` is monkey-patched to raise RuntimeError on network access

### Step 3: Smoke tests

- 7 tests pass in 0.58s: home, month, day-empty, day-error, record-detail,
  search-input, search-results
- Screenshots saved to `presto/tests/fixtures/`
- No network calls triggered

### Step 4: Mise task

- Added `[tasks.test]` to `presto/mise.toml`: `pytest tests/ -v`
- `mise run test` works from the presto directory

### Step 5: Documentation

- Added "Testing" section to `presto/README.md` with usage, coverage table,
  and instructions for adding new tests
- Added "## Testing" section to `presto/AGENTS.md` with conventions

### Key implementation difference from plan

- Did not use `DeviceTest` as base class — instead used pytest session-scoped
  fixtures that call `install_mocks()` and `create_display()` directly. This
  allows clean pytest integration (fixtures, parametrization) without
  unittest.TestCase constraints.
- `import main` happens lazily inside a session-scoped fixture that depends
  on the emulator setup fixture, ensuring mocks are in place before the
  module-level `Presto(full_res=True)` call executes.

### Acceptance criteria #2 (physical deploy) remains unchecked

Cannot verify without physical Presto device. The guard is a no-op when
`PRESTO_TEST_MODE` is unset, so the change is semantically identical to the
original bare `main()` call.

<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->

## Summary

Added a smoke-test harness for the Presto MicroPython application using the pimoroni-emulator's mock system for headless rendering.

### What changed

- **`presto/main.py`** — Added `import os` and wrapped the bare `main()` call with an environment-variable guard (`if os.environ.get("PRESTO_TEST_MODE") != "1":`). The guard is a no-op in normal operation; the emulator and physical deploy paths are unchanged.
- **`presto/tests/`** — New test directory with:
  - `conftest.py` — Session-scoped fixtures that install emulator mocks, create a headless Presto display, import `main` lazily, init pens, and monkey-patch `fetch_thumbnail` to raise on any accidental network call. Provides `make_mock_record()` helper.
  - `test_screens.py` — 7 smoke tests (home, month, day-empty, day-error, record-detail, search-input, search-results), all passing in ~0.6s.
  - `fixtures/` — 7 screenshots generated per run for manual visual inspection.
- **`presto/mise.toml`** — Added `[tasks.test]` task: `pytest tests/ -v`.
- **`presto/README.md`** — Added "Testing" section with usage instructions and coverage table.
- **`presto/AGENTS.md`** — Added "## Testing" section with conventions.

### Tests

```
7 passed in 0.58s
```

All tests use mock data with `_thumb_failed=True` / `_thumb_data=None` so no network calls occur. The `fetch_thumbnail` monkey-patch acts as a safety net.

### Key implementation note

Used pytest session-scoped fixtures calling `install_mocks()` + `create_display()` directly rather than extending `DeviceTest`. This avoids unittest.TestCase constraints and allows clean pytest fixture injection. `import main` happens lazily inside a fixture that depends on the emulator setup, ensuring mock modules are in `sys.modules` before the module-level `Presto(full_res=True)` call executes.

### Outstanding

Acceptance criterion #2 (physical Presto deployment) could not be verified without the device. The guard change is semantically a no-op when `PRESTO_TEST_MODE` is unset — the code path is identical to the original bare `main()` call.

<!-- SECTION:FINAL_SUMMARY:END -->
