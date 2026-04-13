defmodule MusicLibrary.Chats.CollectionChat do
  @moduledoc """
  Chat implementation for the music collection using OpenAI streaming with web search.
  """

  @behaviour MusicLibrary.Chats.StreamProvider

  alias MusicLibrary.Chats.Prompt

  @impl true
  @spec stream_response([map()], {String.t(), non_neg_integer()}, (String.t() -> any())) ::
          :ok | {:error, term()}
  def stream_response(messages, {summary, record_count}, callback) do
    instructions = build_instructions(summary, record_count)

    OpenAI.chat_stream(messages, on_chunk: callback, instructions: instructions, model: "gpt-5.1")
  end

  defp build_instructions(collection_summary, record_count) do
    Prompt.build("""
    Answer questions about the user's music collection.
    Use the provided collection catalog as your primary reference.
    The collection contains #{record_count} records.

    Collection catalog:
    #{collection_summary}
    """)
  end
end
