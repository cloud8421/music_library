defmodule LastFm.APIBehaviour do
  alias LastFm.{Artist, Track}

  @type musicbrainz_id :: String.t()
  @type user :: String.t()
  @type api_key :: String.t()
  @callback get_recent_tracks(user, api_key) :: {:ok, [Track.t()]} | {:error, String.t()}
  @callback get_artist_info(musicbrainz_id, api_key) :: {:ok, Artist.t()} | {:error, String.t()}
end
