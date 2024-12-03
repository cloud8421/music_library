defmodule LastFm.APIBehaviour do
  alias LastFm.{Artist, Config, Track}

  @type musicbrainz_id :: String.t()
  @type config :: Config.t()
  @callback get_recent_tracks(config) :: {:ok, [Track.t()]} | {:error, String.t()}
  @callback get_artist_info(musicbrainz_id, config) :: {:ok, Artist.t()} | {:error, String.t()}
end
