defmodule MusicLibrary.Chats.ArtistChatTest do
  use ExUnit.Case

  alias MusicLibrary.Artists.{Artist, ArtistInfo}
  alias MusicLibrary.Chats.ArtistChat
  alias Plug.Conn

  defp build_artist(attrs \\ %{}) do
    defaults = %{
      musicbrainz_id: Ecto.UUID.generate(),
      name: "Radiohead",
      sort_name: "Radiohead"
    }

    struct!(Artist, Map.merge(defaults, attrs))
  end

  defp build_artist_info(attrs \\ %{}) do
    defaults = %{
      musicbrainz_data: %{
        "area" => %{
          "name" => "United Kingdom",
          "iso-3166-1-codes" => ["GB"]
        }
      },
      wikipedia_data: %{
        "description" => "English rock band",
        "extract" =>
          "Radiohead are an English rock band formed in Abingdon, Oxfordshire, in 1985."
      }
    }

    struct!(ArtistInfo, Map.merge(defaults, attrs))
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

  test "stream_response includes artist context with full info" do
    stub_and_capture_instructions(self())

    artist = build_artist()
    artist_info = build_artist_info()

    assert {:ok, _} = ArtistChat.stream_response([], {artist, artist_info}, fn _chunk -> :ok end)

    assert_receive {:captured_instructions, instructions}
    assert instructions =~ "Name: Radiohead"
    assert instructions =~ "Country: United Kingdom"
    assert instructions =~ "Description: English rock band"
    assert instructions =~ "Biography: Radiohead are an English rock band formed in Abingdon"
  end

  test "stream_response excludes nil wikipedia fields" do
    stub_and_capture_instructions(self())

    artist = build_artist()
    artist_info = build_artist_info(%{wikipedia_data: %{}})

    assert {:ok, _} = ArtistChat.stream_response([], {artist, artist_info}, fn _chunk -> :ok end)

    assert_receive {:captured_instructions, instructions}
    assert instructions =~ "Name: Radiohead"
    assert instructions =~ "Country: United Kingdom"
    refute instructions =~ "Description:"
    refute instructions =~ "Biography:"
    refute instructions =~ "nil"
  end

  test "stream_response handles missing country gracefully" do
    stub_and_capture_instructions(self())

    artist = build_artist()

    artist_info =
      build_artist_info(%{
        musicbrainz_data: %{
          "area" => %{"name" => nil}
        },
        wikipedia_data: %{}
      })

    assert {:ok, _} = ArtistChat.stream_response([], {artist, artist_info}, fn _chunk -> :ok end)

    assert_receive {:captured_instructions, instructions}
    assert instructions =~ "Name: Radiohead"
    # Falls back to "World" when area name is nil
    refute instructions =~ "Country: \n"
  end
end
