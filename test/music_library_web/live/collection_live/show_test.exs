defmodule MusicLibraryWeb.CollectionLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest
  import MusicLibrary.RecordsFixtures
  alias MusicLibrary.Records.Record

  defp escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  defp human_datetime(dt) do
    "#{dt.day}/#{dt.month}/#{dt.year}"
  end

  describe "Edit record from show page" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record_fixture()

      {:ok, show_live, _html} = live(conn, ~p"/collection/#{record.id}")

      assert show_live
             |> element("a", "Edit")
             |> render_click() =~ "Edit"

      assert_patch(show_live, ~p"/collection/#{record}/show/edit")
    end
  end

  describe "Show record" do
    test "it includes all needed information", %{conn: conn} do
      record = record_fixture()

      {:ok, _show_live, html} = live(conn, ~p"/collection/#{record.id}")

      assert html =~ escape(record.title)
      assert html =~ to_string(record.release)
      assert html =~ Record.format_long_label(record.format)
      assert html =~ record.release
      assert html =~ ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"
      assert html =~ human_datetime(record.purchased_at)
      assert html =~ human_datetime(record.inserted_at)
      assert html =~ human_datetime(record.updated_at)

      for artist <- record.artists do
        assert html =~ escape(artist.name)
      end
    end
  end
end
