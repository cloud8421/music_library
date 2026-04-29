defmodule OpenAITest do
  use ExUnit.Case, async: true

  describe "gpt/1" do
    test "delegates to API with resolved config" do
      Req.Test.stub(OpenAI.API, fn conn ->
        assert conn.request_path == "/v1/chat/completions"

        Req.Test.json(conn, %{
          "choices" => [
            %{"message" => %{"content" => ~s({"answer": "42"})}}
          ]
        })
      end)

      completion = %{model: "gpt-4.1-mini", content: "test", role: "user", temperature: 0.5}
      assert {:ok, %{"answer" => "42"}} = OpenAI.gpt(completion)
    end
  end

  describe "embeddings/1" do
    test "delegates to API with resolved config" do
      embedding = [0.1, 0.2, 0.3]

      Req.Test.stub(OpenAI.API, fn conn ->
        assert conn.request_path == "/v1/embeddings"

        Req.Test.json(conn, %{
          "data" => [%{"embedding" => embedding}]
        })
      end)

      assert {:ok, ^embedding} = OpenAI.embeddings("test text")
    end
  end

  describe "chat_stream/2" do
    test "streams chunks via callback" do
      test_pid = self()

      Req.Test.stub(OpenAI.API, fn conn ->
        assert conn.request_path == "/v1/responses"

        body =
          "data: #{JSON.encode!(%{"type" => "response.output_text.delta", "delta" => "Hi"})}\n\n" <>
            "data: #{JSON.encode!(%{"type" => "response.completed"})}\n\n"

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, "Hi"} =
               OpenAI.chat_stream(
                 [%{role: "user", content: "hello"}],
                 on_chunk: fn chunk -> send(test_pid, {:chunk, chunk}) end
               )

      assert_received {:chunk, "Hi"}
    end
  end
end
