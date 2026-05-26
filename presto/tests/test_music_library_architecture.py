"""Behavioral checks for the Elm-style Presto application runtime."""

import pytest

from tests.conftest import make_mock_record


@pytest.fixture(autouse=True)
def _init_display(music_library_module):
    music_library_module.init_display()


def test_status_screen_renders(music_library_module):
    from emulator.testing import screenshot

    app = music_library_module.Model()
    app.screen = music_library_module.STATE_STATUS
    app.status_message = "Loading records..."

    music_library_module.render(app)
    screenshot("tests/fixtures/status-music-library.png")


def test_detail_render_does_not_fetch_cover(music_library_module, monkeypatch):
    app = music_library_module.Model()
    app.screen = music_library_module.STATE_RECORD
    app.detail.selected_index = 0
    app.detail.source_screen = music_library_module.STATE_DAY

    rec = make_mock_record()
    rec["_detail_thumb_failed"] = False
    app.day.records = [rec]

    def _raise_on_fetch(*_args):
        raise RuntimeError("render attempted network work")

    monkeypatch.setattr(music_library_module, "fetch_thumbnail", _raise_on_fetch)

    music_library_module.draw_record_detail(app)


def test_detail_cover_is_prepared_by_effect_message(music_library_module, monkeypatch):
    app = music_library_module.Model()
    rec = make_mock_record()
    rec["_detail_thumb_failed"] = False
    app.day.records = [rec]

    monkeypatch.setattr(
        music_library_module,
        "fetch_thumbnail",
        lambda *_args: b"prepared-jpeg",
    )

    commands = music_library_module.open_record_update(
        app, music_library_module.STATE_DAY, 0
    )
    assert commands == [
        (music_library_module.FX_RENDER,),
        (music_library_module.FX_PREPARE_DETAIL,),
    ]
    assert app.screen == music_library_module.STATE_STATUS

    msg = music_library_module.run_effect(
        app, (music_library_module.FX_PREPARE_DETAIL,)
    )
    assert app.day.records[0]["_detail_thumb_data"] is None

    render_commands = music_library_module.update(app, msg)

    assert app.screen == music_library_module.STATE_RECORD
    assert app.day.records[0]["_detail_thumb_data"] == b"prepared-jpeg"
    assert render_commands == [(music_library_module.FX_RENDER,)]


def test_wake_touch_is_consumed(music_library_module):
    app = music_library_module.Model()
    app.screen = music_library_module.STATE_HOME
    app.touch.display_awake = False

    commands = music_library_module.update(
        app,
        (
            music_library_module.MSG_TOUCH_DOWN,
            music_library_module.HOME_BUTTON_X + 1,
            music_library_module.HOME_BUTTON2_Y + 1,
            1_000,
        ),
    )

    assert commands == [(music_library_module.FX_WAKE_DISPLAY,)]
    assert app.touch.consume_until_release is True
    assert music_library_module.update(app, (music_library_module.MSG_TOUCH_UP,)) == []
    assert app.screen == music_library_module.STATE_HOME


def test_search_effect_reconnects_before_request(music_library_module, monkeypatch):
    app = music_library_module.Model()
    calls = []

    monkeypatch.setattr(music_library_module, "wifi_connected", lambda: False)
    monkeypatch.setattr(
        music_library_module,
        "connect_wifi_effect",
        lambda _app: (calls.append("connect") or True, "127.0.0.1", "token"),
    )
    monkeypatch.setattr(
        music_library_module,
        "fetch_search_results",
        lambda _app, _query: (calls.append("fetch") or [], False),
    )

    msg = music_library_module.load_search_effect(app, "blue")

    assert calls == ["connect", "fetch"]
    assert msg == (music_library_module.MSG_SEARCH_LOADED, [], False, 0)


def test_drag_updates_are_throttled_through_messages(music_library_module):
    app = music_library_module.Model()
    app.screen = music_library_module.STATE_DAY
    app.day.content_height = 1_000
    app.touch.last_touch = 0

    assert music_library_module.update(
        app, (music_library_module.MSG_TOUCH_DOWN, 100, 250, 1_000)
    ) == []

    commands = music_library_module.update(
        app,
        (
            music_library_module.MSG_TOUCH_MOVE,
            150,
            1_000 + music_library_module.DRAG_REDRAW_MS,
        ),
    )

    assert commands == [(music_library_module.FX_RENDER_PARTIAL,)]
    assert app.day.scroll_offset == 100
    assert app.touch.dragging is True
    assert music_library_module.update(
        app, (music_library_module.MSG_TOUCH_UP,)
    ) == [(music_library_module.FX_RENDER_PARTIAL,)]
    assert app.touch.dragging is False
