defmodule OpenAI do
  def gpt_stream(prompt, cb) do
    fun = fn request, finch_request, finch_name, finch_options ->
      fun = fn
        {:status, status}, response ->
          %{response | status: status}

        {:headers, headers}, response ->
          %{response | headers: headers}

        {:data, data}, response ->
          body =
            data
            |> String.split("data: ")
            |> Enum.map(fn str ->
              str
              |> String.trim()
              |> decode_body(cb)
            end)
            |> Enum.filter(fn d -> d != :ok end)

          old_body = if response.body == "", do: [], else: response.body

          %{response | body: old_body ++ body}
      end

      case Finch.stream(finch_request, finch_name, Req.Response.new(), fun, finch_options) do
        {:ok, response} -> {request, response}
        {:error, exception} -> {request, exception}
      end
    end

    Req.post!("https://api.openai.com/v1/chat/completions",
      json: %{
        model: "gpt-4o-mini",
        messages: [%{role: "user", content: prompt}],
        response_format: %{type: "json_object"},
        stream: true,
        temperature: 0.2
      },
      auth: {:bearer, System.fetch_env!("OPENAI_KEY")},
      finch_request: fun
    )
  end

  defp decode_body("", _), do: :ok
  defp decode_body("[DONE]", _), do: :ok
  defp decode_body(json, cb), do: cb.(Jason.decode!(json))
end

{:ok, collector} = Agent.start_link(fn -> "" end)

prompt = """
Provide a list of music genres applicable to the album "Stupid Things that Mean the World" by Tim Bowness.

Limit the list to 5 genres, ordered by decreasing specificity, all lowercase.

Return a valid JSON list.
"""

OpenAI.gpt_stream(prompt, fn data ->
  case get_in(data, ["choices", Access.at(0), "delta", "content"]) do
    nil -> :ok
    data -> Agent.update(collector, fn current -> current <> data end)
  end
end)

Agent.get(collector, & &1) |> Jason.decode!() |> IO.inspect()
