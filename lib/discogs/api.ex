defmodule Discogs.API do
  @moduledoc """
  Interface to the Discogs API.
  """

  alias Discogs.API.ErrorResponse
  alias Req.Request

  require Logger

  @spec get_artist(integer() | String.t(), Discogs.Config.t()) ::
          {:ok, map()} | {:error, ErrorResponse.t() | Exception.t()}
  def get_artist(id, config) do
    config
    |> new_request()
    |> Req.merge(
      headers: %{accept: "application/vnd.discogs.v2.plaintext+json"},
      url: "/artists/#{id}"
    )
    |> get_request()
  end

  @spec get_artist_image(String.t(), Discogs.Config.t()) ::
          {:ok, binary()} | {:error, :cover_not_available}
  def get_artist_image(url, config) do
    case Req.new(url: url, max_retries: 1, user_agent: config.user_agent)
         |> Request.merge_options(config.req_options)
         |> Request.append_request_steps(log_attempt: &log_attempt/1)
         |> Request.append_response_steps(log_error: &log_error/1)
         |> get_request() do
      {:ok, data} -> {:ok, data}
      {:error, _reason} -> {:error, :cover_not_available}
    end
  end

  defp new_request(config) do
    Req.new(
      base_url: "https://api.discogs.com",
      max_retries: 1,
      user_agent: config.user_agent,
      auth: "Discogs token=#{config.personal_access_token}"
    )
    |> Request.merge_options(config.req_options)
    |> Req.RateLimiter.attach(name: :discogs, cooldown: config.api_cooldown)
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
