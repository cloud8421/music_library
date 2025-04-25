defmodule Discogs.API do
  @moduledoc """
  Interface to the Discogs API.
  """

  require Logger

  def get_artist(id, config) do
    config
    |> new_request()
    |> Req.merge(url: "/artists/#{id}")
    |> get_request()
  end

  defp new_request(config) do
    Req.new(
      base_url: "https://api.discogs.com",
      max_retries: 1,
      user_agent: config.user_agent,
      auth: "Discogs token=#{config.personal_access_token}"
    )
    |> Req.Request.merge_options(config.req_options)
    |> Req.Request.append_request_steps(log_attempt: &log_attempt/1)
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
end
