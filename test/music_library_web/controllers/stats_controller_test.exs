defmodule MusicLibraryWeb.StatsControllerTest do
  use MusicLibraryWeb.ConnCase

  alias MusicLibrary.Records.Record

  import MusicLibrary.RecordsFixtures

  defp fill_collection(_) do
    records = Enum.map(1..5, fn _ -> record_fixture() end)
    %{collection: records}
  end

  defp fill_wishlist(_) do
    records = Enum.map(1..30, fn _ -> record_fixture(%{purchased_at: nil}) end)
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
      conn = get(conn, "/")

      response = html_response(conn, 200)

      assert response =~ collection |> length() |> Integer.to_string()

      collection
      |> Enum.frequencies_by(& &1.format)
      |> Enum.each(fn {format, count} ->
        assert response =~ "\n#{count}\n"
        assert response =~ "\n#{Record.format_long_label(format)}\n"
      end)

      collection
      |> Enum.frequencies_by(& &1.type)
      |> Enum.each(fn {type, count} ->
        assert response =~ "\n#{count}\n"
        assert response =~ "\n#{Record.type_long_label(type)}\n"
      end)
    end

    test "it shows the latest purchase", %{conn: conn, collection: collection} do
      latest_record = Enum.max_by(collection, & &1.purchased_at)

      conn = get(conn, "/")

      assert html_response(conn, 200) =~ escape(latest_record.title)

      for artist <- latest_record.artists do
        assert html_response(conn, 200) =~ escape(artist.name)
      end
    end

    test "it shows the wishlist total count", %{conn: conn, wishlist: wishlist} do
      conn = get(conn, "/")

      response = html_response(conn, 200)

      assert response =~ wishlist |> length() |> Integer.to_string()
    end
  end
end
