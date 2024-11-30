defmodule LastFm.APIImpl do
  @behaviour LastFm.APIBehaviour

  require Logger

  alias LastFm.Track

  @base_url "http://ws.audioscrobbler.com/2.0/"

  # Experimental: metrics show some long running requests
  # that end up hitting timeouts (at default values),
  # so we make them shorter to leverage retries
  @request_opts [
    pool_timeout: 1000,
    receive_timeout: 3000,
    request_timeout: 4500
  ]

  @impl true
  def get_recent_tracks(user, api_key) do
    options = [
      method: "user.getrecenttracks",
      user: user,
      api_key: api_key,
      format: "json",
      limit: 50
    ]

    url = @base_url <> "?" <> URI.encode_query(options)

    Logger.debug("Fetching data from #{sanitize_url(url, api_key)}")

    case json_get(url) do
      {:ok, response} ->
        {:ok,
         response
         |> get_in(["recenttracks", "track"])
         |> Track.from_api_response()}

      other ->
        msg = "Failed to fetch data from #{sanitize_url(url, api_key)}, reason: #{inspect(other)}"
        Logger.error(msg)
        {:error, msg}
    end
  end

  defp json_get(url) do
    req =
      Finch.build(:get, url, [
        {"User-Agent", "MusicLibrary/0.1.0 ( cloud8421@gmail.com )"}
      ])

    case Finch.request(req, LastFm.Finch, @request_opts) do
      {:ok, response} when response.status == 200 ->
        Jason.decode(response.body)

      other ->
        other
    end
  end

  defp sanitize_url(url, api_key) do
    String.replace(url, api_key, "<redacted_api_key>")
  end
end
