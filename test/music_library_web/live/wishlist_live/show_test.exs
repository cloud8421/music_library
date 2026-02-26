defmodule MusicLibraryWeb.WishlistLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias MusicLibrary.Assets.Transform
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
      transform = %Transform{hash: record.cover_hash, width: nil}
      payload = Transform.encode!(transform)
      cover_url = ~p"/assets/#{payload}"

      session =
        conn
        |> visit(~p"/wishlist/#{record.id}")
        |> assert_has("h2", text: escape(record.title))
        |> assert_has("p", text: record.release_date)
        |> assert_has("p", text: format_label(record.format))
        |> assert_has("p", text: type_label(record.type))
        |> assert_has("code#record-#{record.id}", text: record.id)
        |> assert_has("code#mb-#{record.musicbrainz_id}", text: record.musicbrainz_id)
        |> assert_has("span", text: "Multi")
        |> assert_has("span", text: "03/05/2004")
        |> assert_has("span", text: "🇬🇧")
        |> assert_has("p", text: Record.format_as_date(record.inserted_at))
        |> assert_has("p", text: Record.format_as_date(record.updated_at))
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
