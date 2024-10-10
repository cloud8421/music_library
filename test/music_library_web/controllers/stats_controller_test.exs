defmodule MusicLibraryWeb.StatsControllerTest do
  use MusicLibraryWeb.ConnCase

  alias MusicLibrary.Records.Record

  import MusicLibrary.RecordsFixtures

  defp create_records(_) do
    records = Enum.map(1..30, fn _ -> record_fixture() end)
    %{records: records}
  end

  defp escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  describe "GET /" do
    setup [:create_records]

    test "it shows the record count (total and by format)", %{conn: conn, records: records} do
      conn = get(conn, "/")

      assert html_response(conn, 200) =~ records |> length() |> Integer.to_string()

      records
      |> Enum.frequencies_by(& &1.format)
      |> Enum.each(fn {format, count} ->
        response = html_response(conn, 200)
        assert response =~ "\n#{count}\n"
        assert response =~ "\n#{Record.format_long_label(format)}\n"
      end)
    end

    test "it shows the latest record", %{conn: conn, records: records} do
      latest_record = Enum.max_by(records, & &1.inserted_at)

      conn = get(conn, "/")

      assert html_response(conn, 200) =~ escape(latest_record.title)

      for artist <- latest_record.artists do
        assert html_response(conn, 200) =~ escape(artist.name)
      end
    end
  end
end
