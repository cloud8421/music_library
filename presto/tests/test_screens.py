"""Smoke tests — verify every Presto screen renders without crashing.

Each test:
1. Creates an ``AppState`` (requires ``init_display`` fixture).
2. Sets the appropriate view state fields.
3. Calls the screen's draw function.
4. Asserts no exception occurred.
5. Saves a screenshot to ``presto/tests/fixtures/`` for manual inspection.

No network calls are made — ``fetch_thumbnail`` is monkey-patched to raise,
and mock records have ``_thumb_failed=True`` / ``_thumb_data=None``.
"""

import pytest

from tests.conftest import make_mock_record


@pytest.mark.usefixtures("init_display")
class TestSmokeScreens:
    """Smoke tests for all 7 Presto screens."""

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _make_app(main_module):
        """Create a fresh ``AppState``."""
        return main_module.AppState()

    @staticmethod
    def _screenshot(main_module, name):
        """Save the current emulator framebuffer to fixtures/."""
        from emulator.testing import screenshot

        path = f"tests/fixtures/{name}.png"
        screenshot(path)

    # ------------------------------------------------------------------
    # Tests
    # ------------------------------------------------------------------

    def test_home_screen_renders(self, main_module):
        """Home / splash screen."""
        app = self._make_app(main_module)
        main_module.draw_home_screen(app)
        self._screenshot(main_module, "home")

    def test_month_view_renders(self, main_module):
        """Month calendar grid."""
        app = self._make_app(main_module)
        app.screen = main_module.STATE_MONTH
        app.view_year = 2026
        app.view_month = 5
        main_module.draw_month_view(app)
        self._screenshot(main_module, "month")

    def test_day_view_empty_renders(self, main_module):
        """Day view with no records."""
        app = self._make_app(main_module)
        app.screen = main_module.STATE_DAY
        app.view_year = 2026
        app.view_month = 5
        app.day.selected_day = 15
        app.day.records = []
        app.day.error = False
        main_module.draw_day_view(app)
        self._screenshot(main_module, "day-empty")

    def test_day_view_error_renders(self, main_module):
        """Day view with error state."""
        app = self._make_app(main_module)
        app.screen = main_module.STATE_DAY
        app.view_year = 2026
        app.view_month = 5
        app.day.selected_day = 15
        app.day.records = []
        app.day.error = True
        main_module.draw_day_view(app)
        self._screenshot(main_module, "day-error")

    def test_record_detail_renders(self, main_module):
        """Record detail view."""
        app = self._make_app(main_module)
        app.screen = main_module.STATE_RECORD
        app.view_year = 2026
        app.view_month = 5
        app.day.selected_day = 15

        rec = make_mock_record(0)
        app.day.records = [rec]
        app.detail.selected_index = 0
        app.detail.source_screen = main_module.STATE_DAY

        main_module.draw_record_detail(app)
        self._screenshot(main_module, "record-detail")

    def test_cover_contract_uses_api_sized_images(self, main_module):
        """Cover helpers use the named API sizes expected by the display."""
        rec = make_mock_record(0)

        assert main_module.THUMB_SIZE == 80
        assert main_module.DETAIL_COVER_SIZE == 460
        assert main_module.DETAIL_COVER_X == 10
        assert main_module._record_thumbnail_url(rec).endswith("/small-0.jpg")
        assert main_module._record_detail_cover_url(rec).endswith("/medium-0.jpg")

    def test_search_input_renders(self, main_module):
        """Search input screen with on-screen keyboard."""
        app = self._make_app(main_module)
        app.screen = main_module.STATE_SEARCH_INPUT
        main_module.draw_search_input(app)
        self._screenshot(main_module, "search-input")

    def test_search_results_renders(self, main_module):
        """Search results list."""
        app = self._make_app(main_module)
        app.screen = main_module.STATE_SEARCH_RESULTS

        # Populate results with mock records
        recs = [make_mock_record(i) for i in range(3)]
        app.search.results = recs

        # Pre-compute content height (prepare_record_list won't trigger
        # network calls because _thumb_failed=True).
        app.search.content_height = main_module.prepare_record_list(app, recs)

        main_module.draw_search_results(app)
        self._screenshot(main_module, "search-results")
