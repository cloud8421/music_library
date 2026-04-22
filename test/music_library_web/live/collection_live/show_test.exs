defmodule MusicLibraryWeb.CollectionLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias MusicBrainz.Fixtures
  alias MusicLibrary.Assets.Transform
  alias MusicLibrary.Records.Record

  describe "Edit record from show page" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record()

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      conn
      |> visit(~p"/collection/#{record.id}")
      |> unwrap(&render_async/1)
      |> assert_has("a", "Edit")
      |> click_link("Edit")
      |> assert_path(~p"/collection/#{record}/show/edit")
    end
  end

  describe "Show record" do
    test "includes all needed information", %{conn: conn} do
      record = record()
      transform = %Transform{hash: record.cover_hash, width: nil}
      payload = Transform.encode!(transform)
      cover_url = ~p"/assets/#{payload}"

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> unwrap(&render_async/1)
        |> assert_has("h2", escape(record.title))
        |> assert_has("p", record.release_date)
        |> assert_has("p", format_label(record.format))
        |> assert_has("p", type_label(record.type))
        |> assert_has("dd", Record.format_as_date(record.purchased_at))
        |> assert_has("code#record-#{record.id}", record.id)
        |> assert_has("code#mb-#{record.musicbrainz_id}", record.musicbrainz_id)
        |> assert_has("span", "Multi")
        |> assert_has("span", "03/05/2004")
        |> assert_has("span", "🇬🇧")
        |> assert_has("p", Record.format_as_date(record.inserted_at))
        |> assert_has("p", Record.format_as_date(record.updated_at))
        |> assert_has("img[src='#{cover_url}']")

      for artist <- record.artists do
        assert_has(session, "a", escape(artist.name))
      end

      for genre <- record.genres do
        assert_has(session, "a", genre)
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
        |> assert_has("button", "Show Tracks")
        |> unwrap(&render_async/1)
        |> assert_has("a", "Connect Last.fm")

      release =
        MusicBrainz.Release.from_api_response(release_response)

      for medium <- release.media do
        session
        |> within("#disc-#{medium.number}", fn inner_session ->
          for track <- medium.tracks do
            inner_session
            |> assert_has("li", escape(track.title))
          end

          inner_session
        end)
      end
    end
  end
end
