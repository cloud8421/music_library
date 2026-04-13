defmodule OpenAI.API do
  @moduledoc """
  Low-level HTTP client for the OpenAI API (chat completions, streaming responses, embeddings).
  """

  require Logger

  @spec gpt(OpenAI.Completion.t(), OpenAI.Config.t()) :: {:ok, map()} | {:error, term()}
  def gpt(completion, config) do
    case config
         |> new_request()
         |> Req.merge(
           url: "/v1/chat/completions",
           receive_timeout: 10_000,
           connect_options: [timeout: 2_500],
           json: %{
             model: completion.model,
             messages: [Map.take(completion, [:content, :role])],
             response_format: %{type: "json_object"},
             temperature: completion.temperature
           }
         )
         |> Req.post() do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        content = get_in(body, ["choices", Access.at(0), "message", "content"])
        JSON.decode(content)

      {:ok, %{body: body}} ->
        {:error, "OpenAI API error: #{inspect(body)}"}

      {:error, exception} ->
        {:error, "Connection error: #{Exception.message(exception)}"}
    end
  end

  @spec chat_stream([map()], String.t(), String.t(), float(), OpenAI.Config.t(), (String.t() ->
                                                                                    any())) ::
          :ok | {:error, String.t()}
  def chat_stream(messages, instructions, model, temperature, config, cb) do
    config
    |> new_request()
    |> Req.merge(
      url: "/v1/responses",
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
      into: fn {:data, data}, {req, resp} ->
        buffer = Req.Request.get_private(req, :sse_buffer, "")
        {events, buffer} = ServerSentEvents.parse(buffer <> data)
        req = Req.Request.put_private(req, :sse_buffer, buffer)

        decode_events(events, cb, req, resp)
      end
    )
    |> do_chat_stream()
  end

  defp decode_events([], _cb, req, resp), do: {:cont, {req, resp}}

  defp decode_events([%{data: json} | rest], cb, req, resp) do
    case decode_responses_event(json, cb) do
      {:error, message} ->
        Logger.error(message)
        {:halt, {req, Req.Response.put_private(resp, :error, message)}}

      _ ->
        decode_events(rest, cb, req, resp)
    end
  end

  defp do_chat_stream(req) do
    case Req.post(req) do
      {:ok, %{status: status} = resp} when status in 200..299 ->
        if message = Req.Response.get_private(resp, :error) do
          {:error, message}
        else
          :ok
        end

      {:ok, %{body: body}} ->
        {:error, "OpenAI API error: #{inspect(body)}"}

      {:error, exception} ->
        {:error, "Connection error: #{Exception.message(exception)}"}
    end
  end

  @spec get_embeddings(String.t(), OpenAI.Config.t()) :: {:ok, [float()]} | {:error, term()}
  def get_embeddings(text, config) do
    resp =
      config
      |> new_request()
      |> Req.merge(
        url: "/v1/embeddings",
        json: %{
          input: text,
          model: "text-embedding-3-small"
        }
      )
      |> Req.post!()

    if resp.status == 200 do
      embeddings = get_in(resp.body, ["data", Access.at(0), "embedding"])
      {:ok, embeddings}
    else
      {:error, resp.body}
    end
  end

  defp new_request(config) do
    Req.new(
      base_url: "https://api.openai.com",
      auth: {:bearer, config.api_key}
    )
    |> Req.Request.merge_options(config.req_options)
    |> Req.RateLimiter.attach(name: :open_ai, cooldown: config.api_cooldown)
    |> Req.Request.append_request_steps(log_attempt: &log_attempt/1)
    |> Req.Request.append_response_steps(log_error: &log_error/1)
  end

  defp decode_responses_event(json, cb) do
    case JSON.decode!(json) do
      %{"type" => "response.output_text.delta", "delta" => delta} ->
        cb.(delta)
        :ok

      %{"type" => "error", "error" => %{"message" => message}} ->
        {:error, message}

      %{"type" => "response.failed", "response" => %{"error" => %{"message" => message}}} ->
        {:error, message}

      %{"type" => "response." <> _} ->
        :ok

      other ->
        Logger.warning(fn ->
          "Unexpected response: #{inspect(other)}"
        end)
    end
  end

  defp log_attempt(request) do
    url = URI.to_string(request.url)
    Logger.debug("Fetching data from #{url}")
    request
  end

  defp log_error({request, response}) do
    if response.status in 400..499 or response.status in 500..599 do
      Logger.error(fn ->
        url = URI.to_string(request.url)
        "Failed to fetch data from #{url}, reason: #{inspect(response.body)}"
      end)
    end

    {request, response}
  end
end
