defmodule MusicLibrary.Chats.ArtistChat do
  @moduledoc """
  Chat implementation for artists using OpenAI streaming with Wikipedia context.
  """

  @behaviour MusicLibrary.Chats.StreamProvider

  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Chats.Prompt

  @impl true
  @spec stream_response([map()], {map(), ArtistInfo.t()}, (String.t() -> any())) ::
          {:ok, String.t()} | {:error, term()}
  def stream_response(messages, {artist, artist_info}, callback) do
    instructions = build_instructions(artist, artist_info)

    OpenAI.chat_stream(messages, on_chunk: callback, instructions: instructions)
  end

  def build_instructions(artist, artist_info) do
    context = build_context(artist, artist_info)

    Prompt.build("""
    Answer questions about the artist the user is currently viewing. \
    Use the provided artist information as your primary reference.

    Artist information:
    #{context}\
    """)
  end

  defp build_context(artist, artist_info) do
    country = ArtistInfo.country(artist_info)
    description = ArtistInfo.wikipedia_description(artist_info)
    summary = ArtistInfo.wikipedia_summary(artist_info)

    parts =
      [
        {"Name", artist.name},
        {"Country", country.name},
        {"Description", description},
        {"Biography", summary}
      ]
      |> Enum.reject(fn {_label, value} -> value in [nil, ""] end)
      |> Enum.map_join("\n", fn {label, value} -> "#{label}: #{value}" end)

    parts
  end
end
