defmodule OpenAI do
  alias OpenAI.API

  def gpt(completion) do
    {:ok, collector} = Agent.start_link(fn -> "" end)

    API.gpt_stream(completion, fn data ->
      case get_in(data, ["choices", Access.at(0), "delta", "content"]) do
        nil -> :ok
        data -> Agent.update(collector, fn current -> current <> data end)
      end
    end)

    result = Agent.get(collector, & &1) |> Jason.decode!()
    Agent.stop(collector)
    {:ok, result}
  end
end
