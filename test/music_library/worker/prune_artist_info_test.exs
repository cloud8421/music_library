defmodule MusicLibrary.Worker.PruneArtistInfoTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ArtistInfoFixtures
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Artists
  alias MusicLibrary.Worker.PruneArtistInfo

  describe "perform/1" do
    test "keeps artist info when artist is still referenced by a record" do
      record = record()
      artist = hd(record.artists)
      artist_info = artist_info(artist.musicbrainz_id)

      assert :ok = perform_job(PruneArtistInfo, %{"id" => artist.musicbrainz_id})

      assert Artists.get_artist_info!(artist_info.id)
    end

    test "deletes artist info when artist is not referenced by any record" do
      artist_info =
        artist_info_fixture(%{musicbrainz_data: %{"name" => "Orphaned Artist"}})

      assert :ok = perform_job(PruneArtistInfo, %{"id" => artist_info.id})

      assert_raise Ecto.NoResultsError, fn ->
        Artists.get_artist_info!(artist_info.id)
      end
    end
  end
end
