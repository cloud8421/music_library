defmodule MusicLibrary.Worker.ArtistRefreshDiscogsDataTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ArtistInfoFixtures
  import MusicLibrary.Fixtures.Records

  alias Discogs.Fixtures.Artist, as: ArtistFixture
  alias MusicLibrary.Artists
  alias MusicLibrary.Worker.ArtistRefreshDiscogsData

  setup do
    record = record()
    artist = hd(record.artists)
    artist_info = artist_info(artist.musicbrainz_id)
    %{artist_info: artist_info}
  end

  describe "perform/1" do
    test "refreshes Discogs data", %{artist_info: artist_info} do
      Req.Test.stub(Discogs.API, fn conn ->
        Req.Test.json(conn, ArtistFixture.get_artist())
      end)

      assert {:ok, _} = perform_job(ArtistRefreshDiscogsData, %{"id" => artist_info.id})

      updated = Artists.get_artist_info!(artist_info.id)
      assert updated.discogs_data != nil
    end

    test "returns ok when no discogs data is available" do
      artist_info =
        artist_info_fixture(%{musicbrainz_data: %{"name" => "No Discogs Artist"}})

      assert {:ok, _} = perform_job(ArtistRefreshDiscogsData, %{"id" => artist_info.id})
    end
  end
end
