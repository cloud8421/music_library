defmodule MusicLibraryWeb.StatsLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest
  import MusicLibrary.RecordsFixtures
  alias MusicLibrary.Records.Record

  defp fill_collection(_) do
    records = Enum.map(1..99, fn _ -> record_fixture() end)
    %{collection: records}
  end

  defp fill_wishlist(_) do
    records = Enum.map(1..101, fn _ -> record_fixture(%{purchased_at: nil}) end)
    %{wishlist: records}
  end

  defp escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  describe "GET /" do
    setup [:fill_collection, :fill_wishlist]

    test "it shows the collection counts (total, format, and type)", %{
      conn: conn,
      collection: collection
    } do
      {:ok, _stats_live, html} = live(conn, "/")

      assert html =~ collection |> length() |> Integer.to_string()

      collection
      |> Enum.frequencies_by(& &1.format)
      |> Enum.each(fn {format, count} ->
        assert html =~ "\n#{count}\n"
        assert html =~ "\n#{Record.format_long_label(format)}\n"
      end)

      collection
      |> Enum.frequencies_by(& &1.type)
      |> Enum.each(fn {type, count} ->
        assert html =~ "\n#{count}\n"
        assert html =~ "\n#{Record.type_long_label(type)}\n"
      end)
    end

    test "it shows the latest purchase", %{conn: conn, collection: collection} do
      # purchased_at has second precision, so finding the latest purchased using then
      # highest purchsed_at value doesn't work, as it picks the wrong value.
      latest_record = List.last(collection)

      {:ok, _stats_live, html} = live(conn, "/")

      assert html =~ escape(latest_record.title)

      for artist <- latest_record.artists do
        assert html =~ escape(artist.name)
      end
    end

    test "it shows the wishlist total count", %{conn: conn, wishlist: wishlist} do
      {:ok, _stats_live, html} = live(conn, "/")

      assert html =~ wishlist |> length() |> Integer.to_string()
    end
  end
end
