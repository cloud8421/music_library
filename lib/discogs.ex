defmodule Discogs do
  alias Discogs.API

  def get_artist(id) do
    discogs_config = discogs_config()

    API.get_artist(id, discogs_config)
  end

  defp discogs_config, do: Discogs.Config.resolve(:music_library)
end
