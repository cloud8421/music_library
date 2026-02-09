defmodule BraveSearch do
  alias BraveSearch.API

  def search_images(query, opts \\ []) do
    API.search_images(query, opts, config())
  end

  def download_image(url) do
    API.download_image(url, config())
  end

  defp config, do: BraveSearch.Config.resolve(:music_library)
end
