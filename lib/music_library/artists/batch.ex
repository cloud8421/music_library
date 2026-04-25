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
    batch(&Artists.refresh_musicbrainz_data_async/1)
  end

  @spec refresh_discogs_data() :: {:ok, [String.t()]}
  def refresh_discogs_data do
    batch(&Artists.refresh_discogs_data_async/1)
  end

  @spec refresh_wikipedia_data() :: {:ok, [String.t()]}
  def refresh_wikipedia_data do
    batch(&Artists.refresh_wikipedia_data_async/1)
  end

  @spec refresh_lastfm_data() :: {:ok, [String.t()]}
  def refresh_lastfm_data do
    batch(&Artists.refresh_lastfm_data_async/1)
  end

  defp batch(callback) do
    Batch.run_on_all(from(r in ArtistInfo), "artist_info", callback)
  end
end
