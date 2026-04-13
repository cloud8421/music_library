defmodule MusicLibrary.Chats.CollectionChatTest do
  use ExUnit.Case

  alias MusicLibrary.Chats.CollectionChat

  defp sse_event(type, data) do
    json = JSON.encode!(%{type: type, delta: data})
    "event: #{type}\ndata: #{json}\n\n"
  end

  defp completed_response do
    sse_event("response.output_text.delta", "Hello") <>
      "event: response.completed\ndata: {\"type\":\"response.completed\"}\n\n"
  end

  defp stub_and_capture_instructions(test_pid) do
    Req.Test.stub(OpenAI.API, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      request = JSON.decode!(body)
      send(test_pid, {:captured_instructions, request["instructions"]})

      conn
      |> Plug.Conn.put_resp_content_type("text/event-stream")
      |> Plug.Conn.send_resp(200, completed_response())
    end)
  end

  test "stream_response includes collection summary in instructions" do
    stub_and_capture_instructions(self())

    summary =
      "Radiohead - OK Computer (1997-06-16, cd, album) [alternative rock, art rock]\nPink Floyd - The Wall (1979-11-30, vinyl, album) [progressive rock]"

    assert :ok = CollectionChat.stream_response([], {summary, 2}, fn _chunk -> :ok end)

    assert_receive {:captured_instructions, instructions}
    assert instructions =~ summary
    assert instructions =~ "music collection"
    assert instructions =~ "collection catalog"
    assert instructions =~ "2 records"
  end

  test "stream_response handles empty collection" do
    stub_and_capture_instructions(self())

    assert :ok = CollectionChat.stream_response([], {"", 0}, fn _chunk -> :ok end)

    assert_receive {:captured_instructions, instructions}
    assert instructions =~ "0 records"
  end
end
