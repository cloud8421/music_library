defmodule DiscogsTest do
  use ExUnit.Case, async: true

  alias Discogs.API.ErrorResponse
  alias Discogs.Fixtures

  describe "ErrorResponse.from_response/1" do
    test "extracts message from body" do
      err = ErrorResponse.from_response(%{status: 429, body: %{"message" => "rate limited"}})
      assert err.message == "rate limited"
      assert err.kind == :rate_limit
    end

    test "fallback message when body has no message key" do
      err = ErrorResponse.from_response(%{status: 500, body: %{"error" => "boom"}})
      assert err.message == nil
      assert err.kind == :server_error
    end

    test "fallback message when body is not a map" do
      err = ErrorResponse.from_response(%{status: 404, body: "not found"})
      assert err.message == nil
      assert err.kind == :not_found
    end
  end

  describe "retry_delay_seconds/1" do
    test "returns 60 for rate_limit" do
      err = ErrorResponse.from_response(%{status: 429, body: %{}})
      assert ErrorResponse.retry_delay_seconds(err) == 60
    end

    test "returns 30 for server_error" do
      err = ErrorResponse.from_response(%{status: 500, body: %{}})
      assert ErrorResponse.retry_delay_seconds(err) == 30
    end

    test "returns 10 for timeout" do
      err = %ErrorResponse{status: nil, message: nil, kind: :timeout, body: nil}
      assert ErrorResponse.retry_delay_seconds(err) == 10
    end

    test "returns 30 as default for non-retryable kinds" do
      err = ErrorResponse.from_response(%{status: 404, body: %{}})
      assert ErrorResponse.retry_delay_seconds(err) == 30
    end
  end

  describe "retryable?/1" do
    test "returns true for rate_limit" do
      err = ErrorResponse.from_response(%{status: 429, body: %{}})
      assert ErrorResponse.retryable?(err)
    end

    test "returns true for server_error" do
      err = ErrorResponse.from_response(%{status: 503, body: %{}})
      assert ErrorResponse.retryable?(err)
    end

    test "returns true for timeout" do
      err = %ErrorResponse{status: nil, message: nil, kind: :timeout, body: nil}
      assert ErrorResponse.retryable?(err)
    end

    test "returns false for not_found" do
      err = ErrorResponse.from_response(%{status: 404, body: %{}})
      refute ErrorResponse.retryable?(err)
    end

    test "returns false for auth_error" do
      err = ErrorResponse.from_response(%{status: 401, body: %{}})
      refute ErrorResponse.retryable?(err)
    end
  end

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
