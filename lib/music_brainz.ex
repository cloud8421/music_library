defmodule MusicBrainz do
  @moduledoc """
  MusicBrainz API facade for release and artist metadata search.
  """

  alias MusicBrainz.API

  @page_size 100

  @type search_opts :: [limit: non_neg_integer(), offset: non_neg_integer()]

  @spec search_release_group(String.t(), search_opts()) ::
          {:ok,
           %{
             total_count: non_neg_integer(),
             release_groups: [MusicBrainz.ReleaseGroupSearchResult.t()]
           }}
          | {:error, term()}
  def search_release_group(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    API.search_release_group(
      query,
      [limit: limit, offset: offset],
      music_brainz_config()
    )
  end

  @spec get_release_group(String.t()) :: {:ok, map()} | {:error, term()}
  def get_release_group(musicbrainz_id) do
    API.get_release_group(musicbrainz_id, music_brainz_config())
  end

  @spec get_releases(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_releases(musicbrainz_id, opts) do
    API.get_releases(musicbrainz_id, opts, music_brainz_config())
  end

  @doc """
  Fetches all releases belonging to the given release group by paging through
  `get_releases/2` until an incomplete page is returned.

  Returns the accumulated list of release maps as returned by
  `MusicBrainz.API.get_releases/3`. On a failure partway through the loop
  the error is returned and accumulated results are discarded.
  """
  @spec get_all_releases(String.t()) :: {:ok, [map()]} | {:error, term()}
  def get_all_releases(release_group_id) do
    fetch_all_releases(release_group_id, [], 0)
  end

  defp fetch_all_releases(release_group_id, acc, offset) do
    opts = [limit: @page_size, offset: offset]

    with {:ok, %{"releases" => page}} <- get_releases(release_group_id, opts) do
      acc = acc ++ page

      if length(page) < @page_size do
        {:ok, acc}
      else
        fetch_all_releases(release_group_id, acc, offset + @page_size)
      end
    end
  end

  @spec get_release(String.t()) :: {:ok, map()} | {:error, term()}
  def get_release(musicbrainz_id) do
    API.get_release(musicbrainz_id, music_brainz_config())
  end

  @spec search_release_by_barcode(String.t()) ::
          {:ok, [MusicBrainz.ReleaseSearchResult.t()]} | {:error, term()}
  def search_release_by_barcode(barcode) do
    API.search_release_by_barcode(barcode, music_brainz_config())
  end

  @spec get_cover_art({:musicbrainz_id, String.t()} | {:url, String.t()}) ::
          {:ok, binary()} | {:error, term()}
  def get_cover_art(id_or_url) do
    API.get_cover_art(id_or_url, music_brainz_config())
  end

  @spec get_artist(String.t()) :: {:ok, MusicBrainz.Artist.t()} | {:error, term()}
  def get_artist(musicbrainz_id) do
    API.get_artist(musicbrainz_id, music_brainz_config())
  end

  defp music_brainz_config, do: MusicBrainz.Config.resolve(:music_library)
end
