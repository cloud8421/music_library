defmodule MusicLibraryWeb.CollectionLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records

  import MusicLibraryWeb.RecordComponents,
    only: [format_label: 1, type_label: 1, selected_release_label: 1]

  alias MusicBrainz.Fixtures
  alias MusicLibrary.Records.Record

  describe "Edit record from show page" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, Fixtures.Release.release(:marbles))
      end)

      conn
      |> visit(~p"/collection/#{record.id}")
      |> assert_has("a", text: "Edit")
      |> click_link("Edit")
      |> assert_path(~p"/collection/#{record}/show/edit")
    end
  end

  describe "Show record" do
    test "it includes all needed information", %{conn: conn} do
      record = record()
      cover_url = ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, Fixtures.Release.release(:marbles))
      end)

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> assert_has("h2", text: escape(record.title))
        |> assert_has("p", text: record.release_date)
        |> assert_has("p", text: format_label(record.format))
        |> assert_has("p", text: type_label(record.type))
        |> assert_has("dd", text: Record.format_as_date(record.purchased_at))
        |> assert_has("dd", text: record.id)
        |> assert_has("a", text: record.musicbrainz_id)
        |> assert_has("dd", text: selected_release_label(record))
        |> assert_has("dd", text: Record.format_as_date(record.inserted_at))
        |> assert_has("dd", text: Record.format_as_date(record.updated_at))
        |> assert_has("img[src='#{cover_url}']")

      for artist <- record.artists do
        assert_has(session, "a", text: escape(artist.name))
      end

      for genre <- record.genres do
        assert_has(session, "a", text: genre)
      end
    end
  end

  describe "Side panel" do
    test "shows a record's tracks", %{conn: conn} do
      record = record()

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> assert_has("button", text: "Show Tracks")
        |> unwrap(fn view ->
          # we can't directly click the "Show Tracks" button as
          # its phx-click event uses a JS command. Bit of a hack, but we can simulate
          # the click by pretending we're dealing with a JS hook, and trigger the event
          # that is sent by the JS command.
          view
          |> Phoenix.LiveViewTest.render_hook(:load_release_with_tracks, %{})
        end)
        |> assert_has("a", text: "Connect your Last.fm account")

      release =
        MusicBrainz.Release.from_api_response(release_response)

      for medium <- release.media do
        session
        |> within("#disc-#{medium.number}", fn inner_session ->
          for track <- medium.tracks do
            inner_session
            |> assert_has("li", text: escape(track.title))
          end

          inner_session
        end)
      end
    end
  end
end
