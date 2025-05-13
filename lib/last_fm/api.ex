defmodule LastFm.API do
  require Logger

  alias LastFm.{Artist, Session, Track}
  alias LastFm.API.{ErrorResponse, Signature}

  def get_session(token, config) do
    params =
      %{
        api_key: config.api_key,
        method: "auth.getSession",
        token: token
      }

    signature = Signature.generate(params, config.shared_secret)

    params = Map.put(params, "api_sig", signature)

    config
    |> new_request()
    |> Req.merge(url: "/", params: params)
    |> Req.Request.append_response_steps(parse_error: &parse_error/1)
    |> Req.Request.append_response_steps(parse_session: &parse_session/1)
    |> get_request()
  end

  def scrobble(tracks, session_key, config) do
    params =
      %{"api_key" => config.api_key, "method" => "track.scrobble", "sk" => session_key}

    track_params =
      tracks
      |> Enum.with_index()
      |> Enum.flat_map(fn {track, index} ->
        track
        |> Enum.map(fn {key, value} ->
          {"#{key}[#{index}]", value}
        end)
      end)
      |> Enum.into(%{})

    params = Map.merge(params, track_params)

    signature = Signature.generate(params, config.shared_secret)

    body = Map.merge(params, %{"api_sig" => signature, "format" => "json"})

    config
    |> new_request()
    |> Req.merge(url: "/", form: body)
    |> post_request()
  end

  def get_recent_tracks(config) do
    params =
      config
      |> base_params()
      |> Keyword.merge(method: "user.getrecenttracks", limit: 50)

    config
    |> new_request()
    |> Req.merge(url: "/", params: params)
    |> Req.Request.append_response_steps(parse_tracks: &parse_tracks/1)
    |> get_request()
  end

  def get_artist_info(id_or_name_option, config) do
    params =
      config
      |> base_params()
      |> Keyword.merge(method: "artist.getInfo")
      |> put_musicbrainz_id_or_name(id_or_name_option)

    config
    |> new_request()
    |> Req.merge(url: "/", params: params)
    |> Req.Request.append_response_steps(parse_tracks: &parse_artist/1)
    |> get_request()
  end

  def get_similar_artists(id_or_name_option, config) do
    params =
      config
      |> base_params()
      |> Keyword.merge(limit: 100, method: "artist.getSimilar")
      |> put_musicbrainz_id_or_name(id_or_name_option)

    config
    |> new_request()
    |> Req.merge(url: "/", params: params)
    |> Req.Request.append_response_steps(parse_tracks: &parse_similar_artists/1)
    |> get_request()
  end

  defp put_musicbrainz_id_or_name(params, {:musicbrainz_id, musicbrainz_id}) do
    Keyword.put(params, :mbid, musicbrainz_id)
  end

  defp put_musicbrainz_id_or_name(params, {:name, name}) do
    Keyword.put(params, :artist, name)
  end

  defp base_params(config) do
    [
      user: config.user,
      api_key: config.api_key,
      format: "json"
    ]
  end

  defp new_request(config) do
    Req.new(
      base_url: "https://ws.audioscrobbler.com/2.0/",
      # Experimental: metrics show some long running requests
      # that end up hitting timeouts (at default values),
      # so we make them shorter to leverage retries
      max_retries: 1,
      pool_timeout: 1000,
      # the maximum number of milliseconds that a pool can be idle before
      # being terminated, Setting it to a low value so that it gets
      # terminated and we don't get failures after the vm resumes.
      pool_max_idle_time: 1000,
      receive_timeout: 1000,
      connect_options: [
        timeout: 2500
      ],
      user_agent: config.user_agent
    )
    |> Req.Request.merge_options(config.req_options)
    |> Req.Request.put_private(:api_key, config.api_key)
    |> Req.Request.append_request_steps(log_attempt: &log_attempt/1)
    |> Req.Request.append_response_steps(parse_error: &parse_error/1)
  end

  defp get_request(request) do
    case Req.get(request) do
      {:ok, %{body: %ErrorResponse{} = error_response}} ->
        {:error, error_response.error}

      {:ok, response} ->
        {:ok, response.body}

      error ->
        error
    end
  end

  defp post_request(request) do
    case Req.post(request) do
      {:ok, %{body: %ErrorResponse{} = error_response}} ->
        {:error, error_response.error}

      {:ok, response} ->
        {:ok, response.body}

      error ->
        error
    end
  end

  defp log_attempt(request) do
    url = URI.to_string(request.url)
    api_key = Req.Request.get_private(request, :api_key)
    Logger.debug("Fetching data from #{sanitize_url(url, api_key)}")
    request
  end

  defp parse_session({request, response}) do
    session = Session.parse(response.body)
    {request, Map.put(response, :body, session)}
  end

  defp parse_error({request, response}) do
    case response.body do
      %{"error" => error_number, "message" => message} ->
        error = ErrorResponse.new(error_number, message)

        Logger.error(fn ->
          url = URI.to_string(request.url)
          api_key = Req.Request.get_private(request, :api_key)
          "Failed to fetch data from #{sanitize_url(url, api_key)}, reason: #{message}."
        end)

        Req.Request.halt(request, Map.put(response, :body, error))

      _other ->
        {request, response}
    end
  end

  defp parse_tracks({request, response}) do
    tracks =
      response.body
      |> get_in(["recenttracks", "track"])
      |> Track.from_api_response()

    {request, Map.put(response, :body, tracks)}
  end

  defp parse_artist({request, response}) do
    artist =
      response.body
      |> Map.get("artist")
      |> Artist.from_api_response()

    {request, Map.put(response, :body, artist)}
  end

  defp parse_similar_artists({request, response}) do
    artists =
      response.body
      |> get_in(["similarartists", "artist"])
      |> Enum.map(&Artist.from_api_response/1)

    {request, Map.put(response, :body, artists)}
  end

  defp sanitize_url(url, api_key) do
    String.replace(url, api_key, "<redacted_api_key>")
  end
end
