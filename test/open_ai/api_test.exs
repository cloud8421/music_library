defmodule OpenAI.APITest do
  use ExUnit.Case, async: true

  alias OpenAI.API
  alias OpenAI.API.ErrorResponse

  @config %OpenAI.Config{
    api_key: "test_key",
    req_options: [plug: {Req.Test, __MODULE__}, max_retries: 0],
    api_cooldown: 0
  }

  describe "gpt/2" do
    test "returns parsed JSON on success" do
      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/v1/chat/completions"

        Req.Test.json(conn, %{
          "choices" => [
            %{"message" => %{"content" => ~s({"result": "hello"})}}
          ]
        })
      end)

      completion = %{model: "gpt-4.1-mini", content: "test", role: "user", temperature: 0.5}
      assert {:ok, %{"result" => "hello"}} = API.gpt(completion, @config)
    end

    @tag :capture_log
    test "returns a rate-limit error response on 429 rate_limit_exceeded" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Plug.Conn.put_resp_header("retry-after", "10")
        |> Plug.Conn.put_resp_header("x-ratelimit-reset-requests", "20s")
        |> Plug.Conn.put_resp_header("x-ratelimit-reset-tokens", "1m30s")
        |> Req.Test.json(%{
          "error" => %{
            "code" => "rate_limit_exceeded",
            "type" => "rate_limit_error",
            "message" => "Rate limit reached"
          }
        })
      end)

      completion = %{model: "gpt-4.1-mini", content: "test", role: "user", temperature: 0.5}

      assert {:error, %ErrorResponse{} = err} = API.gpt(completion, @config)
      assert err.status == 429
      assert err.code == "rate_limit_exceeded"
      assert err.kind == :rate_limit
      assert err.retry_delay_seconds == 90
      assert ErrorResponse.retry_delay_seconds(err) == 90
      assert ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "returns an auth-error response on 429 insufficient_quota (non-retryable)" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{
          "error" => %{
            "code" => "insufficient_quota",
            "type" => "insufficient_quota",
            "message" => "You exceeded your current quota"
          }
        })
      end)

      completion = %{model: "gpt-4.1-mini", content: "test", role: "user", temperature: 0.5}

      assert {:error, %ErrorResponse{} = err} = API.gpt(completion, @config)
      assert err.code == "insufficient_quota"
      assert err.kind == :auth_error
      refute ErrorResponse.retryable?(err)
    end

    @tag :capture_log
    test "returns a server-error response on 500" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "boom"}})
      end)

      completion = %{model: "gpt-4.1-mini", content: "test", role: "user", temperature: 0.5}

      assert {:error, %ErrorResponse{kind: :server_error}} =
               API.gpt(completion, @config)
    end
  end

  describe "get_embeddings/2" do
    test "returns embedding vector on success" do
      embedding = [0.1, 0.2, 0.3]

      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/v1/embeddings"

        Req.Test.json(conn, %{
          "data" => [%{"embedding" => embedding}]
        })
      end)

      assert {:ok, ^embedding} = API.get_embeddings("test text", @config)
    end

    @tag :capture_log
    test "returns a retryable server-error ErrorResponse on 500" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "internal error"}})
      end)

      assert {:error, %ErrorResponse{status: 500, kind: :server_error} = err} =
               API.get_embeddings("test text", @config)

      assert ErrorResponse.retryable?(err)
    end

    test "returns the transport exception on connection failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      assert {:error, %Req.TransportError{reason: :timeout}} =
               API.get_embeddings("test text", @config)
    end
  end

  describe "chat_stream/6" do
    test "streams text deltas via callback" do
      test_pid = self()

      Req.Test.stub(__MODULE__, fn conn ->
        assert conn.request_path == "/v1/responses"

        body =
          "data: #{JSON.encode!(%{"type" => "response.output_text.delta", "delta" => "Hello"})}\n\n" <>
            "data: #{JSON.encode!(%{"type" => "response.output_text.delta", "delta" => " world"})}\n\n" <>
            "data: #{JSON.encode!(%{"type" => "response.completed"})}\n\n"

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      cb = fn chunk -> send(test_pid, {:chunk, chunk}) end

      assert :ok = API.chat_stream([], "instructions", "gpt-4.1", 0.7, @config, cb)
      assert_received {:chunk, "Hello"}
      assert_received {:chunk, " world"}
    end

    test "callback return value does not affect stream processing" do
      Req.Test.stub(__MODULE__, fn conn ->
        body =
          "data: #{JSON.encode!(%{"type" => "response.output_text.delta", "delta" => "Hello"})}\n\n" <>
            "data: #{JSON.encode!(%{"type" => "response.output_text.delta", "delta" => " world"})}\n\n" <>
            "data: #{JSON.encode!(%{"type" => "response.completed"})}\n\n"

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      test_pid = self()

      cb = fn chunk ->
        send(test_pid, {:chunk, chunk})
        {:error, "callback error"}
      end

      assert :ok = API.chat_stream([], "instructions", "gpt-4.1", 0.7, @config, cb)
      assert_received {:chunk, "Hello"}
      assert_received {:chunk, " world"}
    end

    @tag :capture_log
    test "returns an ErrorResponse struct on non-2xx response" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => %{"message" => "server error"}})
      end)

      cb = fn _chunk -> :ok end

      assert {:error, %ErrorResponse{status: 500, kind: :server_error}} =
               API.chat_stream([], "instructions", "gpt-4.1", 0.7, @config, cb)
    end

    test "returns the transport exception on connection failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      cb = fn _chunk -> :ok end

      assert {:error, %Req.TransportError{reason: :timeout}} =
               API.chat_stream([], "instructions", "gpt-4.1", 0.7, @config, cb)
    end

    @tag :capture_log
    test "returns error when stream contains an error event" do
      Req.Test.stub(__MODULE__, fn conn ->
        body =
          "data: #{JSON.encode!(%{"type" => "response.output_text.delta", "delta" => "Hi"})}\n\n" <>
            "data: #{JSON.encode!(%{"type" => "error", "error" => %{"message" => "token limit exceeded"}})}\n\n"

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      test_pid = self()
      cb = fn chunk -> send(test_pid, {:chunk, chunk}) end

      assert {:error, "token limit exceeded"} =
               API.chat_stream([], "instructions", "gpt-4.1", 0.7, @config, cb)

      assert_received {:chunk, "Hi"}
    end

    @tag :capture_log
    test "returns error when stream contains a response.failed event" do
      Req.Test.stub(__MODULE__, fn conn ->
        body =
          "data: #{JSON.encode!(%{"type" => "response.failed", "response" => %{"error" => %{"message" => "content filter triggered"}}})}\n\n"

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      cb = fn _chunk -> :ok end

      assert {:error, "content filter triggered"} =
               API.chat_stream([], "instructions", "gpt-4.1", 0.7, @config, cb)
    end

    @tag :capture_log
    test "halts processing of remaining events after an error" do
      Req.Test.stub(__MODULE__, fn conn ->
        body =
          "data: #{JSON.encode!(%{"type" => "error", "error" => %{"message" => "rate limited"}})}\n\n" <>
            "data: #{JSON.encode!(%{"type" => "response.output_text.delta", "delta" => "should not arrive"})}\n\n"

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      test_pid = self()
      cb = fn chunk -> send(test_pid, {:chunk, chunk}) end

      assert {:error, "rate limited"} =
               API.chat_stream([], "instructions", "gpt-4.1", 0.7, @config, cb)

      refute_received {:chunk, "should not arrive"}
    end

    @tag :capture_log
    test "logs warning for unexpected event types" do
      Req.Test.stub(__MODULE__, fn conn ->
        body =
          "data: #{JSON.encode!(%{"type" => "unknown.event", "foo" => "bar"})}\n\n" <>
            "data: #{JSON.encode!(%{"type" => "response.completed"})}\n\n"

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      cb = fn _chunk -> :ok end

      assert :ok = API.chat_stream([], "instructions", "gpt-4.1", 0.7, @config, cb)
    end
  end
end
