defmodule BraveSearch.API do
  @moduledoc """
  Interface to the Brave Search API.
  """

  alias BraveSearch.API.ErrorResponse
  alias Req.Request

  require Logger

  @spec search_images(String.t(), keyword(), BraveSearch.Config.t()) ::
          {:ok, [map()]} | {:error, ErrorResponse.t() | Exception.t()}
  def search_images(query, opts, config) do
    params = [q: query, count: Keyword.get(opts, :count, 20)]

    case config
         |> new_request()
         |> Req.merge(url: "/res/v1/images/search", params: params)
         |> get_request() do
      {:ok, body} ->
        results =
          body
          |> Map.get("results", [])
          |> Enum.map(fn result ->
            %{
              thumbnail_url: get_in(result, ["thumbnail", "src"]),
              image_url: get_in(result, ["properties", "url"]),
              width: get_in(result, ["properties", "width"]),
              height: get_in(result, ["properties", "height"]),
              title: Map.get(result, "title", ""),
              source: Map.get(result, "source", "")
            }
          end)

        {:ok, results}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @spec download_image(String.t(), BraveSearch.Config.t()) ::
          {:ok, binary()} | {:error, :download_failed}
  def download_image(url, config) do
    case Req.new(url: url, max_retries: 1, user_agent: config.user_agent)
         |> Request.merge_options(config.req_options)
         |> Request.append_request_steps(log_attempt: &log_attempt/1)
         |> Request.append_response_steps(log_error: &log_error/1)
         |> get_request() do
      {:ok, data} -> {:ok, data}
      {:error, _reason} -> {:error, :download_failed}
    end
  end

  defp new_request(config) do
    Req.new(
      base_url: "https://api.search.brave.com",
      max_retries: 1,
      user_agent: config.user_agent,
      headers: %{"x-subscription-token" => config.api_key}
    )
    |> Request.merge_options(config.req_options)
    |> Req.RateLimiter.attach(name: :brave_search, cooldown: config.api_cooldown)
    |> Request.append_request_steps(log_attempt: &log_attempt/1)
    |> Request.append_response_steps(parse_error: &parse_error/1)
  end

  defp get_request(request) do
    case Req.get(request) do
      {:ok, %{status: status, body: body}} when status in 200..299 ->
        {:ok, body}

      {:ok, %{body: %ErrorResponse{} = error}} ->
        {:error, error}

      # Image download path does not attach parse_error; fall back to raw body.
      {:ok, %{body: body}} ->
        {:error, body}

      error ->
        error
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

  defp parse_error({request, %{status: status} = response}) when status not in 200..299 do
    error = ErrorResponse.from_response(response)

    Logger.error(fn ->
      url = URI.to_string(request.url)
      "Failed to fetch data from #{url}, status: #{status}, reason: #{inspect(response.body)}"
    end)

    Request.halt(request, %{response | body: error})
  end

  defp parse_error(tuple), do: tuple
end
