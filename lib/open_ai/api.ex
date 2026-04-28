defmodule OpenAI.API do
  @moduledoc """
  Low-level HTTP client for the OpenAI API (chat completions, streaming responses, embeddings).

  HTTP errors are returned as `OpenAI.API.ErrorResponse` structs, which classify
  rate-limit failures (retryable) separately from billing-quota failures
  (`insufficient_quota` — non-retryable) despite both using HTTP 429.

  Mid-stream failures in `chat_stream/6` come from parsed SSE event payloads
  rather than HTTP responses and remain as message strings passed through the
  stream callback plumbing.

  `chat_stream/6` streams response chunks with `Req`'s `into: :self`, so the
  calling process receives and consumes Req's async body messages while the
  request is active. Call it from a short-lived worker/task process rather than
  directly from a LiveView or GenServer that has unrelated mailbox traffic.
  """

  alias OpenAI.API.ErrorResponse
  alias Req.Request

  require Logger

  @spec gpt(OpenAI.Completion.t(), OpenAI.Config.t()) ::
          {:ok, map()} | {:error, ErrorResponse.t() | Exception.t()}
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

      {:ok, response} ->
        {:error, ErrorResponse.from_response(response)}

      {:error, exception} ->
        {:error, exception}
    end
  end

  @spec chat_stream([map()], String.t(), String.t(), float(), OpenAI.Config.t(), (String.t() ->
                                                                                    any())) ::
          :ok | {:error, ErrorResponse.t() | Exception.t() | String.t()}
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
      into: :self
    )
    |> do_chat_stream(cb)
  end

  defp do_chat_stream(req, cb) do
    case Req.post(req) do
      {:ok, %{status: status} = resp} when status in 200..299 ->
        decode_response_stream(resp.body, cb)

      {:ok, response} ->
        response = decode_async_error_body(response)
        {:error, ErrorResponse.from_response(response)}

      {:error, exception} ->
        {:error, exception}
    end
  end

  defp decode_response_stream(stream, cb) do
    stream
    |> ServerSentEvents.decode_stream()
    |> Enum.reduce_while(:ok, fn %{data: json}, :ok ->
      case decode_responses_event(json) do
        {:ok, delta} ->
          cb.(delta)
          {:cont, :ok}

        {:error, message} ->
          Logger.error(message)
          {:halt, {:error, message}}

        _ ->
          {:cont, :ok}
      end
    end)
  end

  defp decode_async_error_body(%{body: %Req.Response.Async{} = body} = response) do
    body =
      body
      |> Enum.into("")
      |> decode_error_body()

    %{response | body: body}
  end

  defp decode_async_error_body(response), do: response

  defp decode_error_body(body) when is_binary(body) do
    case JSON.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _reason} -> body
    end
  end

  @spec get_embeddings(String.t(), OpenAI.Config.t()) ::
          {:ok, [float()]} | {:error, ErrorResponse.t() | Exception.t()}
  def get_embeddings(text, config) do
    case config
         |> new_request()
         |> Req.merge(
           url: "/v1/embeddings",
           json: %{
             input: text,
             model: "text-embedding-3-small"
           }
         )
         |> Req.post() do
      {:ok, %{status: 200, body: body}} ->
        {:ok, get_in(body, ["data", Access.at(0), "embedding"])}

      {:ok, response} ->
        {:error, ErrorResponse.from_response(response)}

      {:error, exception} ->
        {:error, exception}
    end
  end

  defp new_request(config) do
    Req.new(
      base_url: "https://api.openai.com",
      auth: {:bearer, config.api_key}
    )
    |> Request.merge_options(config.req_options)
    |> Req.RateLimiter.attach(name: :open_ai, cooldown: config.api_cooldown)
    |> Request.append_request_steps(log_attempt: &log_attempt/1)
    |> Request.append_response_steps(log_error: &log_error/1)
  end

  defp decode_responses_event(json) do
    case JSON.decode!(json) do
      %{"type" => "response.output_text.delta", "delta" => delta} ->
        {:ok, delta}

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
