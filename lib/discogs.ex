defmodule Discogs do
  @moduledoc """
  Discogs API facade for artist profiles and images.
  """

  alias Discogs.API

  @spec get_artist(integer() | String.t()) :: {:ok, map()} | {:error, term()}
  def get_artist(id) do
    API.get_artist(id, discogs_config())
  end

  @spec get_artist_image(String.t()) :: {:ok, binary()} | {:error, :cover_not_available}
  def get_artist_image(url) do
    API.get_artist_image(url, discogs_config())
  end

  defp discogs_config, do: Discogs.Config.resolve(:music_library)
end
