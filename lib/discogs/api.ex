defmodule Discogs.API do
  @moduledoc """
  Interface to the Discogs API.
  """

  require Logger

  def get_artist(id, config) do
    config
    |> new_request()
    |> Req.merge(
      headers: %{accept: "application/vnd.discogs.v2.plaintext+json"},
      url: "/artists/#{id}"
    )
    |> get_request()
  end

  def get_artist_image(url, config) do
    case Req.new(url: url, max_retries: 1, user_agent: config.user_agent)
         |> Req.Request.merge_options(config.req_options)
         |> Req.Request.append_request_steps(log_attempt: &log_attempt/1)
         |> Req.Request.append_response_steps(log_error: &log_error/1)
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
    |> Req.Request.merge_options(config.req_options)
    |> Req.RateLimiter.attach(name: :discogs, cooldown: config.api_cooldown)
    |> Req.Request.append_request_steps(log_attempt: &log_attempt/1)
    |> Req.Request.append_response_steps(log_error: &log_error/1)
  end

  defp get_request(request) do
    case Req.get(request) do
      {:ok, response} when response.status == 200 ->
        {:ok, response.body}

      # all non-success responses can be treated as errors
      {:ok, response} ->
        {:error, response.body}

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
end
