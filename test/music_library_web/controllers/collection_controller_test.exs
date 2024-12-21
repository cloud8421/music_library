defmodule MusicLibraryWeb.CollectionControllerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.RecordsFixtures

  defp create_record(_) do
    %{record: record_fixture()}
  end

  describe "GET /api/collection/latest" do
    setup [:create_record]

    test "it returns the latest record", %{conn: conn, record: record} do
      conn = get(conn, ~p"/api/collection/latest")
      assert json_response(conn, 200) == %{"title" => record.title}
    end
  end
end
