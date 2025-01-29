defmodule MusicLibraryWeb.WishlistLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.RecordsFixtures
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]
  alias MusicLibrary.Records.Record

  describe "Edit record from show page" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record()

      conn
      |> visit(~p"/wishlist/#{record.id}")
      |> assert_has("a", text: "Edit")
      |> click_link("Edit")
      |> assert_path(~p"/wishlist/#{record}/show/edit")
    end
  end

  describe "Show record" do
    test "it includes all needed information", %{conn: conn} do
      record = record(purchased_at: nil)
      cover_url = ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"

      session =
        conn
        |> visit(~p"/wishlist/#{record.id}")
        |> assert_has("h2", text: escape(record.title))
        |> assert_has("p", text: record.release)
        |> assert_has("p", text: format_label(record.format))
        |> assert_has("p", text: type_label(record.type))
        |> assert_has("dd", text: record.id)
        |> assert_has("a", text: record.musicbrainz_id)
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
