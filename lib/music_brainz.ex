defmodule MusicBrainz do
  alias MusicBrainz.API

  def search_release_group(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    API.search_release_group(
      query,
      [limit: limit, offset: offset],
      music_brainz_config()
    )
  end

  def get_release_group(musicbrainz_id) do
    API.get_release_group(musicbrainz_id, music_brainz_config())
  end

  def get_releases(musicbrainz_id, opts) do
    API.get_releases(musicbrainz_id, opts, music_brainz_config())
  end

  def get_release(musicbrainz_id) do
    API.get_release(musicbrainz_id, music_brainz_config())
  end

  def search_release_by_barcode(barcode) do
    API.search_release_by_barcode(barcode, music_brainz_config())
  end

  def get_cover_art(id_or_url) do
    API.get_cover_art(id_or_url, music_brainz_config())
  end

  def get_artist(musicbrainz_id) do
    API.get_artist(musicbrainz_id, music_brainz_config())
  end

  def api_cooldown, do: music_brainz_config().api_cooldown

  defp music_brainz_config, do: MusicBrainz.Config.resolve(:music_library)
end
