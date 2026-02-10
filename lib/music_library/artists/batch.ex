defmodule MusicLibrary.Artists.Batch do
  import Ecto.Query

  alias MusicLibrary.Artists
  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Batch

  def refresh_musicbrainz_data do
    Batch.run_on_all(from(r in ArtistInfo), "artist_info", fn artist_info ->
      Artists.refresh_musicbrainz_data_async(artist_info)
    end)
  end

  def refresh_discogs_data do
    Batch.run_on_all(from(r in ArtistInfo), "artist_info", fn artist_info ->
      Artists.refresh_discogs_data_async(artist_info)
    end)
  end

  def refresh_wikipedia_data do
    Batch.run_on_all(from(r in ArtistInfo), "artist_info", fn artist_info ->
      Artists.refresh_wikipedia_data_async(artist_info)
    end)
  end
end
