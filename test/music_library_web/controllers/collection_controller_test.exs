defmodule MusicLibraryWeb.CollectionControllerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records

  defp create_record(_) do
    %{record: record_with_artist("Steven Wilson")}
  end

  defp api_token do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:api_token)
  end

  describe "GET /api/collection/latest" do
    setup [:create_record]

    test "it requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/collection/latest")

      assert conn.status == 401
    end

    test "it returns the latest record", %{conn: conn, record: record} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/collection/latest")

      assert json_response(conn, 200) == %{
               "artists" => ["Steven Wilson"],
               "title" => record.title,
               "cover_url" =>
                 "http://localhost:4002/api/covers/#{record.id}?vsn=#{record.cover_hash}",
               "thumb_url" =>
                 "http://localhost:4002/api/covers/#{record.id}?vsn=#{record.cover_hash}&size=480"
             }
    end
  end

  describe "GET /api/collection/random" do
    setup [:create_record]

    test "it requires authentication", %{conn: conn} do
      conn = get(conn, ~p"/api/collection/latest")

      assert conn.status == 401
    end

    # We're not testing random here - the query is solid enough
    test "it returns a random record", %{conn: conn, record: record} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/collection/random")

      assert json_response(conn, 200) == %{
               "artists" => ["Steven Wilson"],
               "title" => record.title,
               "cover_url" =>
                 "http://localhost:4002/api/covers/#{record.id}?vsn=#{record.cover_hash}",
               "thumb_url" =>
                 "http://localhost:4002/api/covers/#{record.id}?vsn=#{record.cover_hash}&size=480"
             }
    end
  end
end
