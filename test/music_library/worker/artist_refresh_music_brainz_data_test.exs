defmodule MusicLibrary.Worker.ArtistRefreshMusicBrainzDataTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ArtistInfoFixtures

  alias MusicBrainz.Fixtures.Artist, as: ArtistFixture
  alias MusicLibrary.Artists
  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Worker.ArtistRefreshMusicBrainzData

  setup do
    artist_info =
      artist_info_fixture(%{musicbrainz_data: %{"name" => "Steven Wilson"}})

    %{artist_id: artist_info.id}
  end

  describe "perform/1" do
    test "refreshes MusicBrainz data for an artist", %{artist_id: artist_id} do
      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, ArtistFixture.get_artist())
      end)

      assert {:ok, %ArtistInfo{}} =
               perform_job(ArtistRefreshMusicBrainzData, %{"id" => artist_id})

      updated = Artists.get_artist_info!(artist_id)
      assert updated.musicbrainz_data["name"] == "Steven Wilson"
    end
  end
end
