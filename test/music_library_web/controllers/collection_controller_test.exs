defmodule MusicLibraryWeb.CollectionControllerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.RecordsFixtures

  defp create_record(_) do
    %{record: record_fixture_with_artist("Steven Wilson")}
  end

  describe "GET /api/collection/latest" do
    setup [:create_record]

    test "it returns the latest record", %{conn: conn, record: record} do
      conn = get(conn, ~p"/api/collection/latest")

      assert json_response(conn, 200) == %{
               "artists" => ["Steven Wilson"],
               "title" => record.title,
               "cover_url" => "http://localhost:4002/covers/#{record.id}?vsn=#{record.cover_hash}"
             }
    end
  end
end
