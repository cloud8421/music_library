defmodule MusicLibraryWeb.Components.ReleaseTest do
  @moduledoc """
  Integration tests for the Release LiveComponent driven through `CollectionLive.Show`.

  Covers the UI changes introduced by ML-142: the `Finished at` picker, the sticky
  selection bar, the re-enabled per-medium scrobble button, and the fact that all
  three scrobble entry points now use the picker value (initialised to
  `DateTime.utc_now/0` at mount, resettable via the `Now` button).
  """
  use MusicLibraryWeb.ConnCase, async: false

  import MusicLibrary.Fixtures.Records

  import Phoenix.LiveViewTest,
    only: [element: 2, render_change: 2, render_click: 1]

  alias MusicBrainz.Fixtures.Release, as: ReleaseFixtures
  alias MusicLibrary.Secrets
  alias Req.Test

  @finished_at ~U[2026-03-15 21:00:00Z]
  # `@sheet_form` scopes form-change events to the LiveComponent; button
  # clicks are scoped by `[phx-target]` to avoid colliding with the parent
  # LiveView's own scrobble_release button at `lib/music_library_web/live/collection_live/show.ex:58`.
  @sheet_form "#release-with-tracks-sheet-form"

  defp stub_musicbrainz_release(_) do
    Test.stub(MusicBrainz.API, fn conn ->
      case conn.request_path do
        "/ws/2/release/" <> _id ->
          Test.json(conn, ReleaseFixtures.release_with_media(:marbles))

        _ ->
          Test.json(conn, %{})
      end
    end)

    :ok
  end

  defp capture_lastfm_scrobble(_) do
    test_pid = self()

    Test.stub(LastFm.API, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      params = URI.decode_query(body)
      send(test_pid, {:lastfm_scrobble, params})
      Test.json(conn, %{"scrobbles" => %{"@attr" => %{"accepted" => 1}}})
    end)

    :ok
  end

  defp store_lastfm_session_key(_) do
    Secrets.store("last_fm_session_key", "test_session_key")
    :ok
  end

  defp release_with_tracks do
    :marbles
    |> ReleaseFixtures.release_with_media()
    |> MusicBrainz.Release.from_api_response()
  end

  defp first_track_id(release),
    do: release.media |> List.first() |> Map.get(:tracks) |> List.first() |> Map.get(:id)

  defp second_medium_first_track_id(release),
    do: release.media |> Enum.at(1) |> Map.get(:tracks) |> List.first() |> Map.get(:id)

  defp latest_timestamp(params) do
    params
    |> Enum.filter(fn {k, _v} -> String.starts_with?(k, "timestamp[") end)
    |> Enum.map(fn {_k, v} -> String.to_integer(v) end)
    |> Enum.max()
  end

  describe "Finished at picker" do
    setup [:stub_musicbrainz_release, :store_lastfm_session_key, :capture_lastfm_scrobble]

    test "renders 'Finished at' label when Last.fm is connected", %{conn: conn} do
      record = record()

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> assert_has("div[data-part=inner-prefix]", text: "Finished at")
    end

    test "release scrobble uses mount-time utc_now when picker is not modified", %{conn: conn} do
      record = record()
      before_click = DateTime.utc_now()

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> unwrap(fn view ->
        view
        |> element("button[phx-click=scrobble_release][phx-target]")
        |> render_click()
      end)

      after_click = DateTime.utc_now()

      assert_received {:lastfm_scrobble, params}
      latest = latest_timestamp(params)

      # Scrobble timestamps reflect started_at + track offsets, so the latest
      # timestamp is close to the click time (within a couple of seconds).
      assert latest >= DateTime.to_unix(before_click) - 2
      assert latest <= DateTime.to_unix(after_click) + 2
    end

    test "release scrobble uses the picker value when set", %{conn: conn} do
      record = record()

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> unwrap(fn view ->
        view
        |> element(@sheet_form)
        |> render_change(%{"release" => %{"finished_at" => DateTime.to_iso8601(@finished_at)}})

        view
        |> element("button[phx-click=scrobble_release][phx-target]")
        |> render_click()
      end)

      assert_received {:lastfm_scrobble, params}
      assert latest_timestamp(params) == DateTime.to_unix(@finished_at)
    end

    test "reset_to_now event resets the picker back to the current time", %{conn: conn} do
      record = record()

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> unwrap(fn view ->
        view
        |> element(@sheet_form)
        |> render_change(%{"release" => %{"finished_at" => DateTime.to_iso8601(@finished_at)}})

        view
        |> element("button[phx-click=reset_to_now]")
        |> render_click()

        view
        |> element("button[phx-click=scrobble_release][phx-target]")
        |> render_click()
      end)

      now_unix = DateTime.to_unix(DateTime.utc_now())
      assert_received {:lastfm_scrobble, params}
      latest = latest_timestamp(params)

      # After resetting, the scrobble should use `utc_now/0`, not the stale value.
      assert abs(latest - now_unix) < 5
      refute latest == DateTime.to_unix(@finished_at)
    end
  end

  describe "Per-medium scrobble" do
    setup [:stub_musicbrainz_release, :store_lastfm_session_key, :capture_lastfm_scrobble]

    test "medium-2 scrobble fires when a track on medium-1 is selected (AC#3 regression)",
         %{conn: conn} do
      record = record()
      release = release_with_tracks()
      medium_1_track = first_track_id(release)

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> unwrap(fn view ->
        view
        |> element(@sheet_form)
        |> render_change(%{"release" => %{"selected_tracks" => [medium_1_track]}})

        view
        |> element("button[phx-click=scrobble_medium][phx-value-number='2']")
        |> render_click()
      end)
      |> assert_has("#toast-group", text: "Disc scrobbled successfully")

      assert_received {:lastfm_scrobble, params}
      # Medium 2's tracks were scrobbled, not the medium-1 selection.
      medium_2_first_title =
        release.media |> Enum.at(1) |> Map.get(:tracks) |> List.first() |> Map.get(:title)

      assert params["track[0]"] == medium_2_first_title
    end

    test "medium scrobble uses picker value when set", %{conn: conn} do
      record = record()

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> unwrap(fn view ->
        view
        |> element(@sheet_form)
        |> render_change(%{"release" => %{"finished_at" => DateTime.to_iso8601(@finished_at)}})

        view
        |> element("button[phx-click=scrobble_medium][phx-value-number='2']")
        |> render_click()
      end)

      assert_received {:lastfm_scrobble, params}
      assert latest_timestamp(params) == DateTime.to_unix(@finished_at)
    end
  end

  describe "Sticky selection bar" do
    setup [:stub_musicbrainz_release, :store_lastfm_session_key, :capture_lastfm_scrobble]

    test "is hidden when no tracks are selected", %{conn: conn} do
      record = record()

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> refute_has("button", text: "Scrobble selected")
    end

    test "appears with a singular count when one track is selected", %{conn: conn} do
      record = record()
      release = release_with_tracks()
      track_id = first_track_id(release)

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> unwrap(fn view ->
        view
        |> element(@sheet_form)
        |> render_change(%{"release" => %{"selected_tracks" => [track_id]}})
      end)
      |> assert_has("p", text: "1 track selected")
      |> assert_has("button", text: "Scrobble selected")
    end

    test "shows cross-medium copy when selection spans discs", %{conn: conn} do
      record = record()
      release = release_with_tracks()
      t1 = first_track_id(release)
      t2 = second_medium_first_track_id(release)

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> unwrap(fn view ->
        view
        |> element(@sheet_form)
        |> render_change(%{"release" => %{"selected_tracks" => [t1, t2]}})
      end)
      |> assert_has("p", text: "2 tracks selected")
      |> assert_has("span", text: "across 2 discs")
    end

    test "Scrobble selected uses picker value", %{conn: conn} do
      record = record()
      release = release_with_tracks()
      track_id = first_track_id(release)

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> unwrap(fn view ->
        view
        |> element(@sheet_form)
        |> render_change(%{
          "release" => %{
            "selected_tracks" => [track_id],
            "finished_at" => DateTime.to_iso8601(@finished_at)
          }
        })

        view
        |> element("button[phx-click=scrobble_selected_tracks]")
        |> render_click()
      end)

      assert_received {:lastfm_scrobble, params}
      assert latest_timestamp(params) == DateTime.to_unix(@finished_at)
    end
  end
end

defmodule MusicLibraryWeb.Components.ReleaseTest.ShowPrintTest do
  use MusicLibraryWeb.ConnCase, async: false

  import MusicLibrary.Fixtures.Records

  alias MusicBrainz.Fixtures.Release, as: ReleaseFixtures
  alias MusicBrainz.Fixtures.ReleaseGroup
  alias Req.Test

  @rg_id ReleaseGroup.release_group_id(:marbles)
  @release_id ReleaseFixtures.release_id(:marbles)

  defp stub_musicbrainz_release(_) do
    Test.stub(MusicBrainz.API, fn conn ->
      case conn.request_path do
        "/ws/2/release/" <> _id ->
          Test.json(conn, ReleaseFixtures.release_with_media(:marbles))

        _ ->
          Test.json(conn, %{})
      end
    end)

    :ok
  end

  describe "show_print? assign" do
    setup [:stub_musicbrainz_release]

    test "true renders Print tracklist dropdown entries", %{conn: conn} do
      record = record()

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> assert_has("a", text: "Print tracklist")
    end

    test "false hides Print tracklist dropdown entries", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@rg_id}/releases/#{@release_id}")
      |> render_async()
      |> refute_has("a", text: "Print tracklist")
    end
  end
end
