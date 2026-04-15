defmodule MusicLibraryWeb.ScrobbledTracksLive.RulePickerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records
  import MusicLibrary.ScrobbledTracksFixtures
  import Phoenix.LiveViewTest

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

  defp open_rule_picker(view, album_title) do
    render_click(view, "open_rule_picker", %{"album-title" => album_title})
    view
  end

  defp search_picker(view, query) do
    view
    |> form("#rule-picker-navigation form", %{query: query})
    |> render_submit()
  end

  describe "Rule picker modal" do
    setup [:create_track_without_album_mbid]

    test "opens and shows album title", %{conn: conn, track: track} do
      {:ok, view, _html} = live(conn, ~p"/scrobbled-tracks")

      open_rule_picker(view, track.album.title)

      assert has_element?(view, "#rule-picker-modal")
      assert has_element?(view, "h1", "Create Scrobble Rule")
      assert render(view) =~ track.album.title
    end

    test "closes when close event is triggered", %{conn: conn, track: track} do
      {:ok, view, _html} = live(conn, ~p"/scrobbled-tracks")

      open_rule_picker(view, track.album.title)
      assert has_element?(view, "#rule-picker-modal")

      render_click(view, "close_rule_picker")

      refute has_element?(view, "#rule-picker-modal")
    end
  end

  describe "Rule picker search" do
    setup [:create_track_without_album_mbid, :create_collected_record]

    test "searches and displays collected records", %{
      conn: conn,
      track: track,
      collected: collected
    } do
      {:ok, view, _html} = live(conn, ~p"/scrobbled-tracks")

      open_rule_picker(view, track.album.title)
      html = search_picker(view, collected.title)

      assert html =~ collected.title
      assert html =~ "Collected"
    end

    test "filters out records without selected_release_id", %{conn: conn, track: track} do
      no_release =
        record(%{
          title: "No Release Zzzzzz",
          selected_release_id: nil,
          musicbrainz_data: %{}
        })

      assert is_nil(no_release.selected_release_id)

      {:ok, view, _html} = live(conn, ~p"/scrobbled-tracks")

      open_rule_picker(view, track.album.title)
      search_picker(view, "No Release Zzzzzz")

      refute has_element?(
               view,
               "li[phx-click='select_record'][phx-value-record-id='#{no_release.id}']"
             )
    end

    test "shows wishlisted records", %{conn: conn, track: track} do
      wishlisted = record(%{title: "Wish You Were Here", purchased_at: nil})

      {:ok, view, _html} = live(conn, ~p"/scrobbled-tracks")

      open_rule_picker(view, track.album.title)
      html = search_picker(view, wishlisted.title)

      assert html =~ wishlisted.title
      assert html =~ "Wishlisted"
    end

    test "empty search returns no results", %{conn: conn, track: track} do
      {:ok, view, _html} = live(conn, ~p"/scrobbled-tracks")

      open_rule_picker(view, track.album.title)
      html = search_picker(view, "   ")

      refute html =~ "Collected"
      refute html =~ "Wishlisted"
    end
  end

  describe "Rule creation" do
    setup [:create_track_without_album_mbid, :create_collected_record]

    test "creates scrobble rule when record is selected", %{
      conn: conn,
      track: track,
      collected: collected
    } do
      {:ok, view, _html} = live(conn, ~p"/scrobbled-tracks")

      open_rule_picker(view, track.album.title)
      search_picker(view, collected.title)

      view
      |> element("li[phx-click='select_record'][phx-value-record-id='#{collected.id}']")
      |> render_click()

      refute has_element?(view, "#rule-picker-modal")

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

      {:ok, view, _html} = live(conn, ~p"/scrobbled-tracks")

      open_rule_picker(view, track.album.title)
      search_picker(view, collected.title)

      view
      |> element("li[phx-click='select_record'][phx-value-record-id='#{collected.id}']")
      |> render_click()

      # Modal stays open after error
      assert has_element?(view, "#rule-picker-modal")

      # Only the original rule exists, no duplicate was created
      assert length(ScrobbleRules.list_scrobble_rules(type: :album)) == 1
    end
  end
end
