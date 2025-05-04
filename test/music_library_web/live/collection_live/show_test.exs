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
end
