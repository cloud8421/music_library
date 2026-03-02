defmodule OpenAI do
  alias OpenAI.API

  def gpt(completion) do
    API.gpt(completion, api_key())
  end

  def chat_stream(messages, opts \\ []) when is_list(messages) do
    model = Keyword.get(opts, :model, "gpt-4.1")
    temperature = Keyword.get(opts, :temperature, 0.7)
    instructions = Keyword.get(opts, :instructions, "")
    on_chunk = Keyword.fetch!(opts, :on_chunk)

    case API.chat_stream(messages, instructions, model, temperature, api_key(), on_chunk) do
      :ok -> :ok
      {:error, _reason} = error -> error
    end
  end

  def embeddings(text) do
    API.get_embeddings(text, api_key())
  end

  defp api_key do
    Application.get_env(:music_library, __MODULE__)
    |> Keyword.fetch!(:api_key)
  end
end
