defmodule MusicLibraryWeb.RecordShowTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest
  import MusicLibrary.RecordsFixtures
  alias MusicLibrary.Records.Record

  defp escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  describe "Edit record from show page" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/records/#{record.id}")

      assert show_live
             |> element("a", "Edit Metadata")
             |> render_click() =~ "Edit Metadata"

      assert_patch(show_live, ~p"/records/#{record}/show/edit")
    end
  end

  describe "Show record" do
    test "it includes all needed information", %{conn: conn} do
      record = record_fixture()

      {:ok, _show_live, html} = live(conn, ~p"/records/#{record.id}")

      assert html =~ escape(record.title)
      assert html =~ to_string(record.release)
      assert html =~ Record.format_short_label(record.format)
      assert html =~ record.release
      assert html =~ ~p"/images/#{record.id}?vsn=#{record.cover_hash}"

      for artist <- record.artists do
        assert html =~ escape(artist["name"])
      end
    end
  end
end
