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

    def test_record_detail_uses_placeholder_cover_while_dragging(
        self, main_module, monkeypatch
    ):
        """Detail scroll redraws avoid decoding a cached medium JPEG."""
        app = self._make_app(main_module)
        app.screen = main_module.STATE_RECORD
        app.day.selected_day = 15
        app.touch.dragging = True

        rec = make_mock_record(0)
        rec["_detail_thumb_data"] = b"cached-jpeg"
        rec["_detail_thumb_failed"] = False
        app.day.records = [rec]
        app.detail.selected_index = 0
        app.detail.source_screen = main_module.STATE_DAY

        calls = {"jpeg": 0, "placeholder": 0}

        def _count_jpeg(*_args):
            calls["jpeg"] += 1

        def _count_placeholder(*_args):
            calls["placeholder"] += 1

        monkeypatch.setattr(main_module, "draw_jpeg", _count_jpeg)
        monkeypatch.setattr(main_module, "_draw_placeholder", _count_placeholder)

        main_module.draw_record_detail(app)

        assert calls == {"jpeg": 0, "placeholder": 1}

    def test_cover_contract_uses_api_sized_images(self, main_module):
        """Cover helpers use the named API sizes expected by the display."""
        rec = make_mock_record(0)

        assert main_module.THUMB_SIZE == 80
        assert main_module.DETAIL_COVER_SIZE == 400
        assert main_module.DETAIL_COVER_X == 40
        assert main_module._record_thumbnail_url(rec).endswith("/small-0.jpg")
        assert main_module._record_detail_cover_url(rec).endswith("/medium-0.jpg")

    def test_partial_update_uses_region_when_available(self, main_module, monkeypatch):
        """Bounded display updates call the Presto partial update API."""
        calls = []

        monkeypatch.setattr(
            main_module.presto,
            "partial_update",
            lambda *args: calls.append(("partial", args))
        )
        monkeypatch.setattr(
            main_module.presto,
            "update",
            lambda: calls.append(("full", ()))
        )

        main_module._partial_display_update(1, 2, 3, 4)

        assert calls == [("partial", (1, 2, 3, 4))]

    def test_partial_update_falls_back_to_full_update(self, main_module, monkeypatch):
        """Bounded display updates fall back when partial update fails."""
        calls = []

        def _raise_partial(*_args):
            raise RuntimeError("partial update unavailable")

        monkeypatch.setattr(main_module.presto, "partial_update", _raise_partial)
        monkeypatch.setattr(
            main_module.presto,
            "update",
            lambda: calls.append(("full", ()))
        )

        main_module._partial_display_update(1, 2, 3, 4)

        assert calls == [("full", ())]

    def test_day_view_partial_redraw_updates_scroll_viewport(
        self, main_module, monkeypatch
    ):
        """Day-list bounded redraws update only the scroll viewport."""
        app = self._make_app(main_module)
        app.screen = main_module.STATE_DAY
        app.view_year = 2026
        app.view_month = 5
        app.day.selected_day = 15

        recs = [make_mock_record(i) for i in range(3)]
        app.day.records = recs
        app.day.content_height = main_module.prepare_record_list(app, recs)

        calls = []
        monkeypatch.setattr(
            main_module.presto,
            "partial_update",
            lambda *args: calls.append(args)
        )
        monkeypatch.setattr(main_module.presto, "update", lambda: calls.append("full"))

        main_module.draw_day_view(app, partial=True)

        assert calls == [(
            main_module.SCROLL_VIEWPORT_X,
            main_module.SCROLL_VIEWPORT_Y,
            main_module.SCROLL_VIEWPORT_W,
            main_module.SCROLL_VIEWPORT_H,
        )]

    def test_search_query_field_partial_redraw(self, main_module, monkeypatch):
        """Typing in search redraws only the query field row."""
        app = self._make_app(main_module)
        app.screen = main_module.STATE_SEARCH_INPUT
        app.search.query = "blue"

        calls = []
        monkeypatch.setattr(
            main_module.presto,
            "partial_update",
            lambda *args: calls.append(args)
        )
        monkeypatch.setattr(main_module.presto, "update", lambda: calls.append("full"))

        main_module._redraw_search_query_field(app)

        assert calls == [(
            main_module.KB_INPUT_UPDATE_X,
            main_module.KB_INPUT_UPDATE_Y,
            main_module.KB_INPUT_UPDATE_W,
            main_module.KB_INPUT_UPDATE_H,
        )]

    def test_scrobble_button_partial_redraw(self, main_module, monkeypatch):
        """Scrobble feedback redraws only the visible button region."""
        app = self._make_app(main_module)
        app.screen = main_module.STATE_RECORD
        app.day.selected_day = 15

        rec = make_mock_record(0)
        app.day.records = [rec]
        app.detail.selected_index = 0
        app.detail.source_screen = main_module.STATE_DAY
        main_module._measure_detail_content(app, rec)
        app.detail.scroll_offset = main_module._max_detail_scroll_offset(app)

        calls = []
        monkeypatch.setattr(
            main_module.presto,
            "partial_update",
            lambda *args: calls.append(args)
        )
        monkeypatch.setattr(main_module.presto, "update", lambda: calls.append("full"))

        app.detail.scrobble_state = "loading"
        main_module._redraw_scrobble_button(app, rec)

        button_x = (main_module.WIDTH - main_module.SCROBBLE_BUTTON_W) // 2
        button_y = main_module._detail_scrobble_button_y(app)
        update_y = max(button_y, main_module.SCROLL_VIEWPORT_Y)
        update_h = min(
            button_y + main_module.SCROBBLE_BUTTON_H,
            main_module.HEIGHT
        ) - update_y

        assert calls == [(
            button_x,
            update_y,
            main_module.SCROBBLE_BUTTON_W,
            update_h,
        )]

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
