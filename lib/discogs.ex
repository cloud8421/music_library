defmodule Discogs do
  alias Discogs.API

  def get_artist(id) do
    discogs_config = discogs_config()

    API.get_artist(id, discogs_config)
  end

  def get_artist_image(url) do
    discogs_config = discogs_config()

    API.get_artist_image(url, discogs_config)
  end

  def api_cooldown, do: discogs_config().api_cooldown

  defp discogs_config, do: Discogs.Config.resolve(:music_library)
end
