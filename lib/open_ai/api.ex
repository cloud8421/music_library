defmodule OpenAI.API do
  def gpt(completion, api_key) do
    resp =
      Req.post!("https://api.openai.com/v1/chat/completions",
        receive_timeout: 10_000,
        connect_options: [timeout: 2_500],
        json: %{
          model: completion.model,
          messages: [Map.take(completion, [:content, :role])],
          response_format: %{type: "json_object"},
          temperature: completion.temperature
        },
        auth: {:bearer, api_key}
      )

    if resp.status in 200..299 do
      content = get_in(resp.body, ["choices", Access.at(0), "message", "content"])
      {:ok, JSON.decode!(content)}
    else
      {:error, resp.body}
    end
  end

  def chat_stream(messages, instructions, model, temperature, api_key, cb) do
    case Req.post("https://api.openai.com/v1/responses",
           receive_timeout: 60_000,
           connect_options: [timeout: 5_000],
           json: %{
             model: model,
             instructions: instructions,
             input: messages,
             tools: [%{type: "web_search_preview"}],
             stream: true,
             temperature: temperature
           },
           auth: {:bearer, api_key},
           into: fn {:data, data}, {req, resp} ->
             buffer = Req.Request.get_private(req, :sse_buffer, "")
             {events, buffer} = ServerSentEvents.parse(buffer <> data)
             req = Req.Request.put_private(req, :sse_buffer, buffer)

             for %{data: json} <- events do
               decode_responses_event(json, cb)
             end

             {:cont, {req, resp}}
           end
         ) do
      {:ok, %{status: status}} when status in 200..299 -> :ok
      {:ok, %{body: body}} -> {:error, "OpenAI API error: #{inspect(body)}"}
      {:error, exception} -> {:error, "Connection error: #{Exception.message(exception)}"}
    end
  end

  def get_embeddings(text, api_key) do
    resp =
      Req.post!("https://api.openai.com/v1/embeddings",
        json: %{
          input: text,
          model: "text-embedding-3-small"
        },
        auth: {:bearer, api_key}
      )

    if resp.status == 200 do
      embeddings = get_in(resp.body, ["data", Access.at(0), "embedding"])
      {:ok, embeddings}
    else
      {:error, resp.body}
    end
  end

  defp decode_responses_event(json, cb) do
    case JSON.decode!(json) do
      %{"type" => "response.output_text.delta", "delta" => delta} -> cb.(delta)
      _other -> :ok
    end
  end
end
