defmodule MusicLibrary.Chats.CollectionChat do
  @moduledoc """
  Chat implementation for the music collection using OpenAI streaming with web search.
  """

  @behaviour MusicLibrary.Chats.StreamProvider

  alias MusicLibrary.Chats.Prompt

  @impl true
  @spec stream_response([map()], String.t(), (String.t() -> any())) :: :ok | {:error, term()}
  def stream_response(messages, collection_summary, callback) do
    instructions = build_instructions(collection_summary)

    OpenAI.chat_stream(messages, on_chunk: callback, instructions: instructions)
  end

  defp build_instructions(collection_summary) do
    record_count = count_records(collection_summary)

    Prompt.build("""
    Answer questions about the user's music collection. \
    Use the provided collection catalog as your primary reference. \
    The collection contains #{record_count} records.

    Collection catalog:
    #{collection_summary}\
    """)
  end

  defp count_records(""), do: 0

  defp count_records(summary) do
    summary
    |> String.split("\n")
    |> length()
  end
end
