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

  defp api_key do
    Application.get_env(:music_library, __MODULE__)
    |> Keyword.fetch!(:api_key)
  end
end
