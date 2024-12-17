defmodule LastFm.APIBehaviour do
  alias LastFm.{Artist, Config, Track}

  @type musicbrainz_id :: String.t()
  @type name :: String.t()
  @type config :: Config.t()
  @callback get_recent_tracks(config) :: {:ok, [Track.t()]} | {:error, String.t()}
  @callback get_artist_info({:musicbrainz_id, musicbrainz_id} | {:name, name}, config) ::
              {:ok, Artist.t()} | {:error, String.t()}
  @callback get_similar_artists({:musicbrainz_id, musicbrainz_id} | {:name, name}, config) ::
              {:ok, [Artist.t()]} | {:error, String.t()}
end
