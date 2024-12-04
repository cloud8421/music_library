defmodule MusicBrainz.APIBehaviour do
  @type musicbrainz_id :: String.t()
  @type config :: MusicBrainz.Config.t()

  @callback get_release_group(musicbrainz_id, config) :: {:ok, map()} | {:error, String.t()}

  @callback get_release(musicbrainz_id, config) :: {:ok, map()} | {:error, String.t()}

  @callback search_release_group(String.t(), Keyword.t(), config) ::
              {:ok, [map()]} | {:error, String.t()}

  @callback get_cover_art({:musicbrainz_id, musicbrainz_id()} | {:url, String.t()}, config) ::
              {:ok, binary()} | {:error, String.t()}
end
