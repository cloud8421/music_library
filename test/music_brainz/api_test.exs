defmodule MusicBrainz.APITest do
  use ExUnit.Case, async: true

  alias MusicBrainz.API

  @config %MusicBrainz.Config{
    user_agent: "test_agent",
    req_options: [plug: {Req.Test, __MODULE__}, max_retries: 0],
    api_cooldown: 0
  }

  describe "error classification" do
    @tag :capture_log
    test "503 is treated as :rate_limit (MusicBrainz's rate-limit signal, not 429)" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(503)
        |> Req.Test.json(%{"error" => "Your requests are exceeding the allowable rate limit."})
      end)

      assert {:error, %API.ErrorResponse{} = err} =
               API.get_artist("mbid", @config)

      assert err.status == 503
      assert err.kind == :rate_limit
      assert API.ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "429 falls under :rate_limit via default mapping (even though MusicBrainz doesn't use it)" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => "Too many requests"})
      end)

      assert {:error, %API.ErrorResponse{kind: :rate_limit} = err} =
               API.get_artist("mbid", @config)

      assert API.ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "404 is treated as :not_found and is not retryable" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(404)
        |> Req.Test.json(%{"error" => "Not Found"})
      end)

      assert {:error, %API.ErrorResponse{kind: :not_found} = err} =
               API.get_artist("mbid", @config)

      refute API.ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "400 is treated as :client_error and is not retryable" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(400)
        |> Req.Test.json(%{"error" => "Invalid MBID"})
      end)

      assert {:error, %API.ErrorResponse{kind: :client_error} = err} =
               API.get_artist("mbid", @config)

      refute API.ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "500 is treated as :server_error and is retryable" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => "Internal Server Error"})
      end)

      assert {:error, %API.ErrorResponse{kind: :server_error} = err} =
               API.get_artist("mbid", @config)

      assert API.ErrorResponse.retryable?(err)
    end
  end
end
