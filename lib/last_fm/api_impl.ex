defmodule LastFm.APIImpl do
  @behaviour LastFm.APIBehaviour

  require Logger

  alias LastFm.{Artist, Track}

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
  def get_recent_tracks(config) do
    options = [
      method: "user.getrecenttracks",
      user: config.user,
      api_key: config.api_key,
      format: "json",
      limit: 50
    ]

    url = @base_url <> "?" <> URI.encode_query(options)

    Logger.debug("Fetching data from #{sanitize_url(url, config.api_key)}")

    case json_get(url, config.user_agent) do
      {:ok, response} ->
        {:ok,
         response
         |> get_in(["recenttracks", "track"])
         |> Track.from_api_response()}

      other ->
        msg =
          "Failed to fetch data from #{sanitize_url(url, config.api_key)}, reason: #{inspect(other)}"

        Logger.error(msg)
        {:error, msg}
    end
  end

  @impl true
  def get_artist_info({:musicbrainz_id, artist_mbid}, config) do
    do_get_artist_info([mbid: artist_mbid], config)
  end

  def get_artist_info({:name, artist_name}, config) do
    do_get_artist_info([artist: artist_name], config)
  end

  defp do_get_artist_info(options, config) do
    base_options = [
      method: "artist.getInfo",
      api_key: config.api_key,
      user: config.user,
      format: "json",
      limit: 50
    ]

    options = Keyword.merge(base_options, options)

    url = @base_url <> "?" <> URI.encode_query(options)

    Logger.debug("Fetching data from #{sanitize_url(url, config.api_key)}")

    case json_get(url, config.user_agent) do
      {:ok, response} ->
        {:ok,
         response
         |> Map.get("artist")
         |> Artist.from_api_response()}

      error ->
        msg =
          "Failed to fetch data from #{sanitize_url(url, config.api_key)}, reason: #{inspect(error)}"

        Logger.error(msg)
        error
    end
  end

  @impl true
  def get_similar_artists({:name, artist_name}, config) do
    do_get_similar_artists([artist: artist_name], config)
  end

  def get_similar_artists({:musicbrainz_id, artist_mbid}, config) do
    do_get_similar_artists([mbid: artist_mbid], config)
  end

  defp do_get_similar_artists(options, config) do
    base_options = [
      method: "artist.getSimilar",
      api_key: config.api_key,
      format: "json",
      limit: 50
    ]

    options = Keyword.merge(base_options, options)

    url = @base_url <> "?" <> URI.encode_query(options)

    Logger.debug("Fetching data from #{sanitize_url(url, config.api_key)}")

    case json_get(url, config.user_agent) do
      {:ok, response} ->
        {:ok,
         response
         |> get_in(["similarartists", "artist"])
         |> Enum.map(&Artist.from_api_response/1)}

      error ->
        msg =
          "Failed to fetch data from #{sanitize_url(url, config.api_key)}, reason: #{inspect(error)}"

        Logger.error(msg)
        error
    end
  end

  defp json_get(url, user_agent) do
    req =
      Finch.build(:get, url, [
        {"User-Agent", user_agent}
      ])

    case Finch.request(req, LastFm.Finch, @request_opts) do
      {:ok, response} when response.status == 200 ->
        Jason.decode(response.body)
        |> identify_body()

      other ->
        other
    end
  end

  defp sanitize_url(url, api_key) do
    String.replace(url, api_key, "<redacted_api_key>")
  end

  defp identify_body({:ok, error = %{"error" => _error_number, "message" => _message}}) do
    {:error, error}
  end

  defp identify_body(other), do: other
end
