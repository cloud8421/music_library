defmodule MusicBrainz do
  def search_release_group(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    music_brainz_config().api.search_release_group(
      query,
      [limit: limit, offset: offset],
      music_brainz_config()
    )
  end

  def get_release_group(musicbrainz_id) do
    music_brainz_config().api.get_release_group(musicbrainz_id, music_brainz_config())
  end

  def get_releases(musicbrainz_id, opts) do
    music_brainz_config().api.get_releases(musicbrainz_id, opts, music_brainz_config())
  end

  def get_release(musicbrainz_id) do
    music_brainz_config().api.get_release(musicbrainz_id, music_brainz_config())
  end

  def search_release_by_barcode(barcode) do
    music_brainz_config().api.search_release_by_barcode(barcode, music_brainz_config())
  end

  def get_cover_art(id_or_url) do
    music_brainz_config().api.get_cover_art(id_or_url, music_brainz_config())
  end

  defp music_brainz_config, do: MusicBrainz.Config.resolve(:music_library)
end
