defmodule MusicLibraryWeb.CollectionLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.RecordsFixtures
  alias MusicLibrary.Records.Record

  defp escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  describe "Edit record from show page" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record()

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

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> assert_has("h2", text: escape(record.title))
        |> assert_has("p", text: record.release)
        |> assert_has("p", text: Record.format_long_label(record.format))
        |> assert_has("p", text: Record.type_long_label(record.type))
        |> assert_has("dd", text: Record.format_as_date(record.purchased_at))
        |> assert_has("dd", text: Record.format_as_date(record.inserted_at))
        |> assert_has("dd", text: Record.format_as_date(record.updated_at))
        |> unwrap(fn show_view ->
          html = render(show_view)
          assert html =~ ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"
          html
        end)

      for artist <- record.artists do
        assert_has(session, "a", text: escape(artist.name))
      end
    end
  end
end
