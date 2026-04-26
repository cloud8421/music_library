defmodule OpenAI do
  @moduledoc """
  OpenAI API facade for text embeddings and streaming chat.
  """

  alias OpenAI.API

  @type chat_stream_opts :: [
          model: String.t(),
          temperature: float(),
          instructions: String.t(),
          on_chunk: (String.t() -> any())
        ]

  @spec gpt(OpenAI.Completion.t()) :: {:ok, map()} | {:error, term()}
  def gpt(completion) do
    API.gpt(completion, open_ai_config())
  end

  @spec chat_stream([map()], chat_stream_opts()) :: :ok | {:error, term()}
  def chat_stream(messages, opts \\ []) when is_list(messages) do
    model = Keyword.get(opts, :model, "gpt-4.1")
    temperature = Keyword.get(opts, :temperature, 0.7)
    instructions = Keyword.get(opts, :instructions, "")
    on_chunk = Keyword.fetch!(opts, :on_chunk)

    API.chat_stream(messages, instructions, model, temperature, open_ai_config(), on_chunk)
  end

  @spec embeddings(String.t()) :: {:ok, [float()]} | {:error, term()}
  def embeddings(text) do
    API.get_embeddings(text, open_ai_config())
  end

  defp open_ai_config, do: OpenAI.Config.resolve(:music_library)
end
