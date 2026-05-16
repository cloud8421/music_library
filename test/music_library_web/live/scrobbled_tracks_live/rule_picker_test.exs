defmodule MusicLibraryWeb.ScrobbledTracksLive.RulePickerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records
  import MusicLibrary.ScrobbledTracksFixtures

  import Phoenix.LiveViewTest,
    only: [
      render_submit: 1,
      render_click: 1,
      render_click: 2,
      render_click: 3,
      form: 3,
      element: 2
    ]

  alias MusicLibrary.ScrobbleRules

  defp create_track_without_album_mbid(_) do
    track =
      track_fixture(%{
        title: "Comfortably Numb",
        artist_name: "Pink Floyd",
        album_title: "The Wall",
        album_musicbrainz_id: ""
      })

    %{track: track}
  end

  defp create_collected_record(_) do
    collected = record(%{title: "The Wall", purchased_at: DateTime.utc_now()})
    %{collected: collected}
  end

  defp open_rule_picker(session, album_title) do
    unwrap(session, fn view ->
      render_click(view, "open_rule_picker", %{"album-title" => album_title})
    end)
  end

  defp search_picker(session, query) do
    unwrap(session, fn view ->
      view
      |> form("#rule-picker-navigation form", %{query: query})
      |> render_submit()
    end)
  end

  describe "Rule picker modal" do
    setup [:create_track_without_album_mbid]

    test "opens and shows album title", %{conn: conn, track: track} do
      conn
      |> visit(~p"/scrobbled-tracks")
      |> open_rule_picker(track.album.title)
      |> assert_has("#rule-picker-modal")
      |> assert_has("h1", "Create Scrobble Rule")
      |> assert_has("*", track.album.title)
    end

    test "closes when close event is triggered", %{conn: conn, track: track} do
      session =
        conn
        |> visit(~p"/scrobbled-tracks")
        |> open_rule_picker(track.album.title)

      assert_has(session, "#rule-picker-modal")

      session
      |> unwrap(fn view -> render_click(view, "close_rule_picker") end)
      |> refute_has("#rule-picker-modal")
    end
  end

  describe "Rule picker search" do
    setup [:create_track_without_album_mbid, :create_collected_record]

    test "searches and displays collected records", %{
      conn: conn,
      track: track,
      collected: collected
    } do
      conn
      |> visit(~p"/scrobbled-tracks")
      |> open_rule_picker(track.album.title)
      |> search_picker(collected.title)
      |> assert_has("p", collected.title)
      |> assert_has("h3", "Collected")
    end

    test "filters out records without selected_release_id", %{conn: conn, track: track} do
      no_release =
        record(%{
          title: "No Release Zzzzzz",
          selected_release_id: nil,
          musicbrainz_data: %{}
        })

      assert is_nil(no_release.selected_release_id)

      conn
      |> visit(~p"/scrobbled-tracks")
      |> open_rule_picker(track.album.title)
      |> search_picker("No Release Zzzzzz")
      |> refute_has("li[phx-click='select_record'][phx-value-record-id='#{no_release.id}']")
    end

    test "shows wishlisted records", %{conn: conn, track: track} do
      wishlisted = record(%{title: "Wish You Were Here", purchased_at: nil})

      conn
      |> visit(~p"/scrobbled-tracks")
      |> open_rule_picker(track.album.title)
      |> search_picker(wishlisted.title)
      |> assert_has("p", wishlisted.title)
      |> assert_has("h3", "Wishlisted")
    end

    test "empty search returns no results", %{conn: conn, track: track} do
      conn
      |> visit(~p"/scrobbled-tracks")
      |> open_rule_picker(track.album.title)
      |> search_picker("   ")
      |> refute_has("h3", "Collected")
      |> refute_has("h3", "Wishlisted")
    end
  end

  describe "Rule creation" do
    setup [:create_track_without_album_mbid, :create_collected_record]

    test "creates scrobble rule when record is selected", %{
      conn: conn,
      track: track,
      collected: collected
    } do
      conn
      |> visit(~p"/scrobbled-tracks")
      |> open_rule_picker(track.album.title)
      |> search_picker(collected.title)
      |> unwrap(fn view ->
        view
        |> element("li[phx-click='select_record'][phx-value-record-id='#{collected.id}']")
        |> render_click()
      end)
      |> refute_has("#rule-picker-modal")

      [rule] = ScrobbleRules.list_scrobble_rules(type: :album)
      assert rule.match_value == track.album.title
      assert rule.target_musicbrainz_id == collected.selected_release_id
      assert rule.type == :album
      assert rule.enabled == true
    end

    test "shows error for duplicate rule", %{conn: conn, track: track, collected: collected} do
      {:ok, _rule} =
        ScrobbleRules.create_scrobble_rule(%{
          type: :album,
          match_value: track.album.title,
          target_musicbrainz_id: Ecto.UUID.generate()
        })

      session =
        conn
        |> visit(~p"/scrobbled-tracks")
        |> open_rule_picker(track.album.title)
        |> search_picker(collected.title)
        |> unwrap(fn view ->
          view
          |> element("li[phx-click='select_record'][phx-value-record-id='#{collected.id}']")
          |> render_click()
        end)

      # Modal stays open after error
      assert_has(session, "#rule-picker-modal")

      # Only the original rule exists, no duplicate was created
      assert length(ScrobbleRules.list_scrobble_rules(type: :album)) == 1
    end
  end
end
