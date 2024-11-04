defmodule LastFm.API do
  require Logger

  @base_url "http://ws.audioscrobbler.com/2.0/"

  def get_recent_tracks(user, api_key) do
    options = [
      method: "user.getrecenttracks",
      user: user,
      api_key: api_key,
      format: "json",
      limit: 20
    ]

    url = @base_url <> "?" <> URI.encode_query(options)

    Logger.debug("Fetching data from #{sanitize_url(url, api_key)}")

    case json_get(url) do
      {:ok, response} ->
        {:ok,
         response
         |> get_in(["recenttracks", "track"])
         |> parse_tracks()}

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

    case Finch.request(req, MusicLibrary.Finch) do
      {:ok, response} when response.status == 200 ->
        Jason.decode(response.body)

      other ->
        other
    end
  end

  defmodule Artist do
    defstruct [:musicbrainz_id, :name]
  end

  defmodule Album do
    defstruct [:musicbrainz_id, :title]
  end

  defmodule Track do
    @moduledoc """
    Data is not always guaranteed:

    - musicbrainz_id can be an empty string
    """
    defstruct [
      :musicbrainz_id,
      :title,
      :artist,
      :album,
      :cover_url,
      :scrobbled_at_uts,
      :scrobbled_at_label
    ]
  end

  defp parse_tracks(raw_tracks) do
    Enum.map(raw_tracks, fn t ->
      album = %Album{
        musicbrainz_id: t["album"]["mbid"],
        title: t["album"]["#text"]
      }

      artist = %Artist{
        musicbrainz_id: t["artist"]["mbid"],
        name: t["artist"]["#text"]
      }

      %Track{
        musicbrainz_id: t["mbid"],
        title: t["name"],
        artist: artist,
        album: album,
        cover_url: parse_cover_url(t),
        scrobbled_at_uts: parse_scrobble_at_uts(t),
        scrobbled_at_label: t["date"]["#text"]
      }
    end)
  end

  defp parse_cover_url(track) do
    track["image"]
    |> Enum.find(%{"#text" => nil}, fn i -> i["size"] == "small" end)
    |> Map.get("#text")
  end

  defp parse_scrobble_at_uts(track) do
    track["date"]["uts"]
    |> String.to_integer()
  end

  defp sanitize_url(url, api_key) do
    String.replace(url, api_key, "<redacted_api_key>")
  end
end
