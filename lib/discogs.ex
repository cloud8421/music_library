defmodule Discogs do
  alias Discogs.API

  @spec get_artist(integer() | String.t()) :: {:ok, map()} | {:error, term()}
  def get_artist(id) do
    discogs_config = discogs_config()

    API.get_artist(id, discogs_config)
  end

  @spec get_artist_image(String.t()) :: {:ok, binary()} | {:error, :cover_not_available}
  def get_artist_image(url) do
    discogs_config = discogs_config()

    API.get_artist_image(url, discogs_config)
  end

  defp discogs_config, do: Discogs.Config.resolve(:music_library)
end
