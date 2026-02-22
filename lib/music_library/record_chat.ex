defmodule MusicLibrary.RecordChat do
  alias MusicLibrary.Records.Record

  def stream_response(messages, record, embedding_text, callback) do
    system_prompt = build_system_prompt(record, embedding_text)

    full_messages = [
      %{role: "system", content: system_prompt} | messages
    ]

    OpenAI.chat_stream(full_messages, on_chunk: callback)
  end

  defp build_system_prompt(%Record{} = record, embedding_text) do
    context =
      case embedding_text do
        nil -> basic_context(record)
        "" -> basic_context(record)
        text -> text
      end

    """
    You are a knowledgeable music assistant. Answer questions about the album \
    the user is currently viewing. Use the provided information as your primary \
    reference. Be concise and accurate. When unsure, say so.

    Album information:
    #{context}
    """
  end

  defp basic_context(%Record{} = record) do
    artist_names = Record.artist_names(record)
    genres = Enum.join(record.genres || [], ", ")

    """
    Album: #{record.title}
    Artists: #{artist_names}
    Genres: #{genres}
    Released: #{record.release_date || "Unknown"}
    Type: #{record.type}
    Format: #{record.format}
    """
    |> String.trim()
  end
end
