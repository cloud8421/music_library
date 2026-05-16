defmodule MusicLibraryWeb.CollectionControllerTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records

  alias MusicBrainz.Fixtures.Release, as: ReleaseFixtures
  alias MusicLibrary.Assets.Transform
  alias MusicLibrary.Secrets
  alias Req.Test

  defp create_record(_) do
    %{record: record_with_artist("Steven Wilson", %{release_date: "2025-06-21"})}
  end

  defp api_token do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:api_token)
  end

  describe "authentication" do
    test "all API endpoints require a bearer token", %{conn: conn} do
      for {method, path} <- [
            {:get, ~p"/api/v1/collection/latest"},
            {:get, ~p"/api/v1/collection/random"},
            {:get, ~p"/api/v1/collection"},
            {:get, ~p"/api/v1/collection/on_this_day"},
            {:post, ~p"/api/v1/collection/nonexistent/scrobble"}
          ] do
        conn =
          case method do
            :get -> get(conn, path)
            :post -> post(conn, path)
          end

        assert conn.status == 401,
               "expected 401 for unauthenticated #{String.upcase(to_string(method))} #{path}"
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

    test "filters records when q param matches", %{conn: conn} do
      beatles = record_with_artist("The Beatles", %{title: "Abbey Road"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/collection?q=beatles")

      assert json_response(conn, 200) == %{
               "total" => 1,
               "limit" => 20,
               "offset" => 0,
               "records" => [expected_record_json(beatles)]
             }
    end

    test "returns all records when q is empty string", %{conn: conn, record: record} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/collection?q=")

      assert json_response(conn, 200) == %{
               "total" => 1,
               "limit" => 20,
               "offset" => 0,
               "records" => [expected_record_json(record)]
             }
    end

    test "returns empty results when q matches nothing", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/collection?q=nonexistentxyz")

      assert json_response(conn, 200) == %{
               "total" => 0,
               "limit" => 20,
               "offset" => 0,
               "records" => []
             }
    end

    test "respects pagination with search query", %{conn: conn} do
      _a = record_with_artist("The Beatles", %{title: "Abbey Road"})
      b = record_with_artist("The Beatles", %{title: "Revolver"})
      _c = record_with_artist("The Beatles", %{title: "Sgt Pepper"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/collection?q=beatles&limit=1&offset=1")

      assert json_response(conn, 200) == %{
               "total" => 3,
               "limit" => 1,
               "offset" => 1,
               "records" => [expected_record_json(b)]
             }
    end

    test "response shape is unchanged when searching", %{conn: conn} do
      beatles = record_with_artist("The Beatles", %{title: "Abbey Road"})

      conn =
        conn
        |> put_req_header("authorization", "Bearer #{api_token()}")
        |> get(~p"/api/v1/collection?q=beatles")

      response = json_response(conn, 200)
      assert %{"total" => 1, "limit" => 20, "offset" => 0, "records" => [record_json]} = response
      assert record_json == expected_record_json(beatles)
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

  describe "POST /api/v1/collection/:record_id/scrobble" do
    defp stub_musicbrainz_release(_) do
      Test.stub(MusicBrainz.API, fn conn ->
        case conn.request_path do
          "/ws/2/release/" <> _id ->
            Test.json(conn, ReleaseFixtures.release_with_media(:marbles))

          _ ->
            Test.json(conn, %{})
        end
      end)

      :ok
    end

    defp stub_lastfm_success(_) do
      Test.stub(LastFm.API, fn conn ->
        Test.json(conn, %{"scrobbles" => %{"@attr" => %{"accepted" => 1}}})
      end)

      :ok
    end

    defp stub_lastfm_error(_) do
      Test.stub(LastFm.API, fn conn ->
        Test.json(conn, %{
          "error" => 16,
          "message" => "The service is temporarily unavailable"
        })
      end)

      :ok
    end

    defp stub_musicbrainz_error(_) do
      Test.stub(MusicBrainz.API, fn conn ->
        Plug.Conn.send_resp(conn, 503, "service unavailable")
      end)

      :ok
    end

    defp store_session_key(_) do
      Secrets.store("last_fm_session_key", "test_session_key")

      on_exit(fn ->
        Secrets.store("last_fm_session_key", nil)
      end)

      :ok
    end

    defp auth_header(conn) do
      put_req_header(conn, "authorization", "Bearer #{api_token()}")
    end

    setup [:create_record]

    test "returns 401 without bearer token", %{conn: conn, record: record} do
      conn = post(conn, ~p"/api/v1/collection/#{record.id}/scrobble")

      assert conn.status == 401
    end

    test "returns 404 for non-existent record", %{conn: conn} do
      conn =
        conn
        |> auth_header()
        |> post(~p"/api/v1/collection/00000000-0000-0000-0000-000000000000/scrobble")

      assert json_response(conn, 404) == %{
               "status" => "error",
               "reason" => "not_found"
             }
    end

    test "returns 422 when record has no selected_release_id", %{conn: conn} do
      record = record_with_artist("No Release Artist", %{selected_release_id: nil})

      conn =
        conn
        |> auth_header()
        |> post(~p"/api/v1/collection/#{record.id}/scrobble")

      assert json_response(conn, 422) == %{
               "status" => "error",
               "reason" => "no_selected_release"
             }
    end

    @tag scrobble_success: true
    test "returns 200 when scrobble succeeds", %{conn: conn, record: record} do
      stub_musicbrainz_release(nil)
      stub_lastfm_success(nil)
      store_session_key(nil)

      conn =
        conn
        |> auth_header()
        |> post(~p"/api/v1/collection/#{record.id}/scrobble")

      assert json_response(conn, 200) == %{"status" => "ok"}
    end

    @tag :capture_log
    test "returns 502 when MusicBrainz API fails", %{conn: conn, record: record} do
      stub_musicbrainz_error(nil)

      conn =
        conn
        |> auth_header()
        |> post(~p"/api/v1/collection/#{record.id}/scrobble")

      assert json_response(conn, 502) == %{
               "status" => "error",
               "reason" => "musicbrainz_error"
             }
    end

    @tag :capture_log
    test "returns 502 when Last.fm API fails", %{conn: conn, record: record} do
      stub_musicbrainz_release(nil)
      stub_lastfm_error(nil)
      store_session_key(nil)

      conn =
        conn
        |> auth_header()
        |> post(~p"/api/v1/collection/#{record.id}/scrobble")

      assert json_response(conn, 502) == %{
               "status" => "error",
               "reason" => "lastfm_error"
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
      "selected_release_id" => record.selected_release_id,
      "purchased_at" => record.purchased_at |> DateTime.to_iso8601(),
      "artists" => Enum.map(record.artists, & &1.name),
      "title" => record.title,
      "covers" => %{
        "original" => asset_url(record.cover_hash, nil),
        "large" => asset_url(record.cover_hash, 1000),
        "medium" => asset_url(record.cover_hash, 400),
        "small" => asset_url(record.cover_hash, 80)
      }
    }
  end

  defp asset_url(cover_hash, width) do
    payload = Transform.new(hash: cover_hash, width: width)

    "http://localhost:4002#{~p"/api/v1/assets/#{payload}"}"
  end
end
