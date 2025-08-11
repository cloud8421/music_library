defmodule OpenAI.API do
  # Lifted from https://fly.io/phoenix-files/streaming-openai-responses/
  def gpt_stream(completion, api_key, cb) do
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
        {:error, exception, _response} -> {request, exception}
      end
    end

    Req.post!("https://api.openai.com/v1/chat/completions",
      receive_timeout: 1000,
      connect_options: [
        timeout: 2500
      ],
      json: %{
        model: completion.model,
        messages: [Map.take(completion, [:content, :role])],
        response_format: %{type: "json_object"},
        stream: true,
        temperature: completion.temperature
      },
      auth: {:bearer, api_key},
      finch_request: fun
    )
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

  defp decode_body("", _), do: :ok
  defp decode_body("[DONE]", _), do: :ok
  defp decode_body(json, cb), do: cb.(JSON.decode!(json))
end
