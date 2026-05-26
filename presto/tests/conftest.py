"""Presto smoke test configuration and helpers.

Uses the pimoroni-emulator's mock system so the Presto entrypoints can be
imported on CPython without real MicroPython hardware. The emulator's
headless display is set up as a session-scoped fixture.
"""

import importlib
import sys
from pathlib import Path

import pytest

# Ensure the presto directory is on sys.path so `import main` works.
_presto_dir = Path(__file__).resolve().parent.parent
if str(_presto_dir) not in sys.path:
    sys.path.insert(0, str(_presto_dir))

# ---------------------------------------------------------------------------
# Emulator session setup
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session")
def _emulator():
    """Install mock MicroPython modules and create a headless Presto display.

    This must run before ``main`` is imported because ``main.py`` imports
    ``presto``, ``network``, ``picographics`` etc. at module level.
    """
    from emulator import _emulator_state
    from emulator.devices import get_device
    from emulator.display import create_display
    from emulator.mocks import install_mocks

    device = get_device("presto")
    _emulator_state["device"] = device
    _emulator_state["running"] = True
    _emulator_state["headless"] = True

    install_mocks()

    display = create_display(device, headless=True)
    _emulator_state["display"] = display
    display.init()

    yield

    _emulator_state["running"] = False
    display.close()


# ---------------------------------------------------------------------------
# Module fixture - render both complete entrypoints
# ---------------------------------------------------------------------------

@pytest.fixture(scope="session", params=("main", "music_library"))
def main_module(_emulator, request):
    """Import each application after emulator mocks are installed.

    The ``__name__ == "__main__"`` guards ensure ``main()`` does not run.
    ``fetch_thumbnail`` is monkey-patched to raise on any network call.
    """
    module = importlib.import_module(request.param)

    # Guard against accidental network access in smoke tests.
    def _raise_on_network(*_args, **_kwargs):
        raise RuntimeError("Network call in smoke test - use mock data")

    module.fetch_thumbnail = _raise_on_network

    return module


@pytest.fixture(scope="session")
def music_library_module(_emulator):
    """Import the architecture-based application for transition tests."""
    return importlib.import_module("music_library")


# ---------------------------------------------------------------------------
# Per-class display initialisation
# ---------------------------------------------------------------------------

@pytest.fixture(scope="class")
def init_display(main_module):
    """Call ``init_display()`` once per test class so pens are ready."""
    main_module.init_display()


# ---------------------------------------------------------------------------
# Mock record helper (plain function — no main import needed)
# ---------------------------------------------------------------------------

def make_mock_record(index=0):
    """Return a fully-populated mock record dict for smoke tests.

    Every key required by draw functions is pre-populated.  Thumbnail
    cache entries are set to ``None`` / ``True`` so the renderer uses
    grey placeholders and never calls ``fetch_thumbnail``.
    """
    title = f"Mock Album {index}"
    artist = f"Mock Artist {index}"
    return {
        # API-level fields
        "id": f"rec-{index}",
        "selected_release_id": f"release-uuid-{index}",
        "title": title,
        "artists": [artist],
        "format": "Vinyl",
        "release_date": "1959-08-17",
        "genres": ["Jazz", "Modal"],
        "record_type": "LP",
        "purchased_at": "2024-03-15",
        "covers": {
            "original": f"https://example.com/covers/original-{index}.jpg",
            "large": f"https://example.com/covers/large-{index}.jpg",
            "medium": f"https://example.com/covers/medium-{index}.jpg",
            "small": f"https://example.com/covers/small-{index}.jpg",
        },
        # Pre-computed display strings (row view)
        "_display_title": title,
        "_display_artists": artist,
        "_display_meta": "Vinyl | 1959",
        "_display_title_lines": [(title, 120)],
        "_display_artist_lines": [(artist, 120)],
        "_display_meta_lines": [("Vinyl | 1959", 120)],
        # Thumbnail cache (row view) – force placeholder
        "_thumb_url": "",
        "_thumb_data": None,
        "_thumb_failed": True,
        # Detail-view cache keys
        "_detail_thumb_data": None,
        "_detail_thumb_failed": True,
        "_detail_title_lines": [(title, 22)],
        "_detail_artist_lines": [(artist, 15)],
        "_detail_genre_lines": [("Jazz, Modal", 15)],
        "_detail_meta_lines": [("LP | Vinyl | 1959", 15)],
        "_detail_purchased_lines": [("Purchased: 2024-03-15", 15)],
        # Row height (computed by prepare_record_list)
        "_row_height": 88,
    }
