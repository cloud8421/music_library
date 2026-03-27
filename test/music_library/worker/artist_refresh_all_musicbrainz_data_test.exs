defmodule MusicLibrary.Worker.ArtistRefreshAllMusicBrainzDataTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Worker.ArtistRefreshAllMusicBrainzData

  describe "perform/1" do
    test "enqueues refresh jobs for all artist infos" do
      record = record()
      artist = hd(record.artists)
      artist_info = artist_info(artist.musicbrainz_id)

      assert {:ok, []} = perform_job(ArtistRefreshAllMusicBrainzData, %{})

      assert_enqueued worker: MusicLibrary.Worker.ArtistRefreshMusicBrainzData,
                      args: %{id: artist_info.id}
    end
  end
end
