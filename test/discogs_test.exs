defmodule DiscogsTest do
  use ExUnit.Case, async: true

  alias Discogs.API.ErrorResponse
  alias Discogs.Fixtures

  describe "get_artist/1" do
    test "returns the artist" do
      discogs_id = "discogs_id"

      expected_info =
        Fixtures.Artist.get_artist()

      Req.Test.stub(Discogs.API, fn %{request_path: "/artists/discogs_id"} = conn ->
        Req.Test.json(conn, expected_info)
      end)

      assert {:ok, expected_info} == Discogs.get_artist(discogs_id)
    end

    @tag :capture_log
    test "returns a rate-limit ErrorResponse on 429" do
      Req.Test.stub(Discogs.API, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"message" => "You are making requests too quickly."})
      end)

      assert {:error, %ErrorResponse{} = err} = Discogs.get_artist("1")
      assert err.status == 429
      assert err.kind == :rate_limit
      assert ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "returns a not-found ErrorResponse on 404" do
      Req.Test.stub(Discogs.API, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"message" => "The requested resource was not found."})
      end)

      assert {:error, %ErrorResponse{kind: :not_found} = err} =
               Discogs.get_artist("1")

      refute ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "returns a server-error ErrorResponse on 500" do
      Req.Test.stub(Discogs.API, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"message" => "Internal server error"})
      end)

      assert {:error, %ErrorResponse{kind: :server_error} = err} =
               Discogs.get_artist("1")

      assert ErrorResponse.retryable?(err)
    end
  end
end
