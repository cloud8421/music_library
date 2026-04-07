defmodule OpenAI.APITest do
  use ExUnit.Case, async: true

  alias OpenAI.API

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
    test "returns error on non-2xx response" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => "rate limited"})
      end)

      completion = %{model: "gpt-4.1-mini", content: "test", role: "user", temperature: 0.5}
      assert {:error, _} = API.gpt(completion, @config)
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
    test "returns error on non-200 response" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => "internal error"})
      end)

      assert {:error, _} = API.get_embeddings("test text", @config)
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

    @tag :capture_log
    test "returns error on non-2xx response" do
      Req.Test.stub(__MODULE__, fn conn ->
        conn
        |> Plug.Conn.put_status(500)
        |> Req.Test.json(%{"error" => "server error"})
      end)

      cb = fn _chunk -> :ok end

      assert {:error, "OpenAI API error:" <> _} =
               API.chat_stream([], "instructions", "gpt-4.1", 0.7, @config, cb)
    end

    test "returns error on connection failure" do
      Req.Test.stub(__MODULE__, fn conn ->
        Req.Test.transport_error(conn, :timeout)
      end)

      cb = fn _chunk -> :ok end

      assert {:error, "Connection error:" <> _} =
               API.chat_stream([], "instructions", "gpt-4.1", 0.7, @config, cb)
    end
  end
end
