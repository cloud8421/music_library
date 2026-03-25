defmodule MusicLibrary.Artists.Batch do
  @moduledoc """
  Batch operations for artists: refresh MusicBrainz, Discogs, Wikipedia, and Last.fm data.
  """

  import Ecto.Query

  alias MusicLibrary.Artists
  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Batch

  @spec refresh_musicbrainz_data() :: {:ok, [String.t()]}
  def refresh_musicbrainz_data do
    Batch.run_on_all(from(r in ArtistInfo), "artist_info", fn artist_info ->
      Artists.refresh_musicbrainz_data_async(artist_info)
    end)
  end

  @spec refresh_discogs_data() :: {:ok, [String.t()]}
  def refresh_discogs_data do
    Batch.run_on_all(from(r in ArtistInfo), "artist_info", fn artist_info ->
      Artists.refresh_discogs_data_async(artist_info)
    end)
  end

  @spec refresh_wikipedia_data() :: {:ok, [String.t()]}
  def refresh_wikipedia_data do
    Batch.run_on_all(from(r in ArtistInfo), "artist_info", fn artist_info ->
      Artists.refresh_wikipedia_data_async(artist_info)
    end)
  end

  @spec refresh_lastfm_data() :: {:ok, [String.t()]}
  def refresh_lastfm_data do
    Batch.run_on_all(from(r in ArtistInfo), "artist_info", fn artist_info ->
      Artists.refresh_lastfm_data_async(artist_info.id)
    end)
  end
end
