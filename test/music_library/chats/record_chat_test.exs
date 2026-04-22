defmodule MusicLibrary.Chats.RecordChatTest do
  use ExUnit.Case

  alias MusicLibrary.Artists.Artist
  alias MusicLibrary.Chats.RecordChat
  alias MusicLibrary.Records.Record
  alias Plug.Conn

  defp build_record(attrs \\ %{}) do
    defaults = %{
      title: "OK Computer",
      type: :album,
      format: :cd,
      genres: ["alternative rock", "art rock"],
      release_date: "1997-06-16",
      artists: [
        %Artist{
          musicbrainz_id: Ecto.UUID.generate(),
          name: "Radiohead",
          sort_name: "Radiohead"
        }
      ]
    }

    struct!(Record, Map.merge(defaults, attrs))
  end

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
      {:ok, body, conn} = Conn.read_body(conn)
      request = JSON.decode!(body)
      send(test_pid, {:captured_instructions, request["instructions"]})

      conn
      |> Conn.put_resp_content_type("text/event-stream")
      |> Conn.send_resp(200, completed_response())
    end)
  end

  test "stream_response uses embedding text when present" do
    stub_and_capture_instructions(self())

    record = build_record()
    embedding_text = "Radiohead - OK Computer (1997). Alternative rock masterpiece."

    assert :ok = RecordChat.stream_response([], {record, embedding_text}, fn _chunk -> :ok end)

    assert_receive {:captured_instructions, instructions}
    assert instructions =~ embedding_text
    refute instructions =~ "Album: OK Computer"
  end

  test "stream_response falls back to basic context when embedding text is nil" do
    stub_and_capture_instructions(self())

    record = build_record()

    assert :ok = RecordChat.stream_response([], {record, nil}, fn _chunk -> :ok end)

    assert_receive {:captured_instructions, instructions}
    assert instructions =~ "Album: OK Computer"
    assert instructions =~ "Artists: Radiohead"
    assert instructions =~ "Genres: alternative rock, art rock"
    assert instructions =~ "Released: 1997-06-16"
    assert instructions =~ "Type: album"
    assert instructions =~ "Format: cd"
  end

  test "stream_response falls back to basic context when embedding text is empty" do
    stub_and_capture_instructions(self())

    record = build_record()

    assert :ok = RecordChat.stream_response([], {record, ""}, fn _chunk -> :ok end)

    assert_receive {:captured_instructions, instructions}
    assert instructions =~ "Album: OK Computer"
    assert instructions =~ "Artists: Radiohead"
  end

  test "stream_response handles missing optional fields gracefully" do
    stub_and_capture_instructions(self())

    record = build_record(%{genres: nil, release_date: nil})

    assert :ok = RecordChat.stream_response([], {record, nil}, fn _chunk -> :ok end)

    assert_receive {:captured_instructions, instructions}
    assert instructions =~ "Genres: \n"
    assert instructions =~ "Released: Unknown"
  end
end
