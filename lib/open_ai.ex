defmodule OpenAI do
  alias OpenAI.API

  def gpt(completion) do
    {:ok, collector} = Agent.start_link(fn -> "" end)

    API.gpt_stream(completion, api_key(), fn data ->
      case get_in(data, ["choices", Access.at(0), "delta", "content"]) do
        nil -> :ok
        data -> Agent.update(collector, fn current -> current <> data end)
      end
    end)

    result = Agent.get(collector, & &1) |> JSON.decode!()
    Agent.stop(collector)
    {:ok, result}
  end

  def chat_stream(messages, opts \\ []) do
    model = Keyword.get(opts, :model, "gpt-4o-mini")
    temperature = Keyword.get(opts, :temperature, 0.7)
    on_chunk = Keyword.fetch!(opts, :on_chunk)

    API.chat_stream(messages, model, temperature, api_key(), on_chunk)
  end

  def embeddings(text) do
    API.get_embeddings(text, api_key())
  end

  defp api_key do
    Application.get_env(:music_library, __MODULE__)
    |> Keyword.fetch!(:api_key)
  end
end
