defmodule MusicLibraryWeb.WishlistLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias MusicLibrary.Assets.Transform
  alias MusicLibrary.Records.Record
  alias Phoenix.PubSub

  describe "Edit record from show page" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record(purchased_at: nil)

      conn
      |> visit(~p"/wishlist/#{record.id}")
      |> assert_has("a", "Edit")
      |> click_link("Edit")
      |> assert_path(~p"/wishlist/#{record}/show/edit")
    end
  end

  describe "Show record" do
    test "includes all needed information", %{conn: conn} do
      record = record(purchased_at: nil)
      transform = %Transform{hash: record.cover_hash, width: nil}
      payload = Transform.encode!(transform)
      cover_url = ~p"/assets/#{payload}"

      session =
        conn
        |> visit(~p"/wishlist/#{record.id}")
        |> assert_has("h2", escape(record.title))
        |> assert_has("p", record.release_date)
        |> assert_has("p", format_label(record.format))
        |> assert_has("p", type_label(record.type))
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

  describe "handle_info({:update, record}) with live_action guard" do
    test "updates record when showing (live_action is :show)", %{conn: conn} do
      record = record(purchased_at: nil)
      updated_record = %{record | title: "Background Updated Title"}

      session =
        conn
        |> visit(~p"/wishlist/#{record.id}")

      PubSub.broadcast(
        MusicLibrary.PubSub,
        "records:#{record.id}",
        {:update, updated_record}
      )

      session
      |> assert_has("*", text: "Background Updated Title", timeout: 200)
      |> assert_has("#toast-group", text: "Record updated in the background")
    end

    test "skips update when editing and shows warning toast", %{conn: conn} do
      record = record(purchased_at: nil)
      updated_record = %{record | title: "Should Not Appear"}

      session =
        conn
        |> visit(~p"/wishlist/#{record.id}")
        |> click_link("Edit")

      PubSub.broadcast(
        MusicLibrary.PubSub,
        "records:#{record.id}",
        {:update, updated_record}
      )

      session
      |> refute_has("h2", text: "Should Not Appear")
      |> assert_has(
        "#toast-group",
        text:
          "Record was updated in the background. Your edits may be stale — save and re-open to see the latest data."
      )
    end

    test "no-ops when broadcasted record has mismatched ID", %{conn: conn} do
      record = record(purchased_at: nil)
      other_record = record(purchased_at: nil)

      session =
        conn
        |> visit(~p"/wishlist/#{record.id}")

      PubSub.broadcast(
        MusicLibrary.PubSub,
        "records:#{record.id}",
        {:update, other_record}
      )

      session
      |> assert_has("h2", text: escape(record.title))
      |> refute_has("#toast-group", text: "Record updated in the background")
    end
  end
end
