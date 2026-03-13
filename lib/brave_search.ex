defmodule BraveSearch do
  @moduledoc """
  Brave Search API facade for cover art and artist image search.
  """

  alias BraveSearch.API

  @spec search_images(String.t(), keyword()) :: {:ok, [map()]} | {:error, term()}
  def search_images(query, opts \\ []) do
    API.search_images(query, opts, config())
  end

  @spec download_image(String.t()) :: {:ok, binary()} | {:error, :download_failed}
  def download_image(url) do
    API.download_image(url, config())
  end

  defp config, do: BraveSearch.Config.resolve(:music_library)
end
