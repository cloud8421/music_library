defmodule MusicBrainz.APIBehaviour do
  @type musicbrainz_id :: String.t()

  @callback get_release_group(musicbrainz_id) :: {:ok, map()} | {:error, String.t()}

  @callback get_release(musicbrainz_id) :: {:ok, map()} | {:error, String.t()}

  @callback search_release_group(String.t(), Keyword.t()) :: {:ok, [map()]} | {:error, String.t()}

  @callback get_cover_art({:musicbrainz_id, musicbrainz_id()} | {:url, String.t()}) ::
              {:ok, binary()} | {:error, String.t()}
end
