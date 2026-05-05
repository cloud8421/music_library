defmodule MusicLibraryWeb.CollectionControllerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records

  defp create_record(_) do
    %{record: record_with_artist("Steven Wilson", %{release_date: "2025-06-21"})}
  end

  defp api_token do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:api_token)
  end

  describe "authentication" do
    test "all API endpoints require a bearer token", %{conn: conn} do
      for path <- [
            ~p"/api/v1/collection/latest",
            ~p"/api/v1/collection/random",
            ~p"/api/v1/collection",
            ~p"/api/v1/collection/on_this_day"
          ] do
        assert get(conn, path).status == 401,
               "expected 401 for unauthenticated GET #{path}"
      end
    end
  end

  describe "GET /api/v1/collection/latest" do
    setup [:create_record]

    test "returns the latest record", %{conn: conn, record: record} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/collection/latest")

      assert json_response(conn, 200) == expected_record_json(record)
    end
  end

  describe "GET /api/v1/collection/random" do
    setup [:create_record]

    # We're not testing random here - the query is solid enough
    test "returns a random record", %{conn: conn, record: record} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/collection/random")

      assert json_response(conn, 200) == expected_record_json(record)
    end
  end

  describe "GET /api/v1/collection" do
    setup [:create_record]

    test "returns a paginated list of records", %{conn: conn, record: record} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/collection")

      assert json_response(conn, 200) == %{
               "total" => 1,
               "limit" => 20,
               "offset" => 0,
               "records" => [expected_record_json(record)]
             }
    end
  end

  describe "GET /api/v1/collection/on_this_day" do
    setup [:create_record]

    test "returns a list of records", %{conn: conn, record: record} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/collection/on_this_day?date=2025-06-21")

      assert json_response(conn, 200) == %{
               "records" => [expected_record_json(record)]
             }
    end
  end

  defp expected_record_json(record) do
    %{
      "id" => record.id,
      "type" => record.type |> to_string(),
      "format" => record.format |> to_string(),
      "musicbrainz_id" => record.musicbrainz_id,
      "genres" => record.genres,
      "release_date" => record.release_date,
      "purchased_at" => record.purchased_at |> DateTime.to_iso8601(),
      "artists" => Enum.map(record.artists, & &1.name),
      "title" => record.title,
      "cover_url" =>
        "http://localhost:4002/api/v1/assets/eyJoYXNoIjoiNTk5NDA3RERGNjk5MDdENEE2MEZFMTNDQ0FBODI0RDI1Q0YwOERDMTI0RkQ2QUEzRThFN0VDRDk4Qzg4NUZGRSIsIndpZHRoIjpudWxsfQ",
      "thumb_url" =>
        "http://localhost:4002/api/v1/assets/eyJoYXNoIjoiNTk5NDA3RERGNjk5MDdENEE2MEZFMTNDQ0FBODI0RDI1Q0YwOERDMTI0RkQ2QUEzRThFN0VDRDk4Qzg4NUZGRSIsIndpZHRoIjo0ODB9",
      "mini_cover_url" =>
        "http://localhost:4002/api/v1/assets/eyJoYXNoIjoiNTk5NDA3RERGNjk5MDdENEE2MEZFMTNDQ0FBODI0RDI1Q0YwOERDMTI0RkQ2QUEzRThFN0VDRDk4Qzg4NUZGRSIsIndpZHRoIjoxNTB9"
    }
  end
end
