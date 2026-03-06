defmodule MusicLibrary.Worker.FetchArtistImageTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ArtistInfoFixtures
  import MusicLibrary.Fixtures.Records

  alias Discogs.Fixtures.Artist
  alias MusicLibrary.Artists
  alias MusicLibrary.Worker.FetchArtistImage

  setup do
    record = record()
    artist = hd(record.artists)
    artist_info = artist_info(artist.musicbrainz_id)
    %{artist_info: artist_info}
  end

  describe "perform/1" do
    test "fetches and stores artist image", %{artist_info: artist_info} do
      Req.Test.stub(Discogs.API, fn conn ->
        Plug.Conn.send_resp(conn, 200, Artist.image_data())
      end)

      assert :ok = perform_job(FetchArtistImage, %{"id" => artist_info.id})

      updated = Artists.get_artist_info!(artist_info.id)
      assert updated.image_data_hash != nil
    end

    test "cancels when no discogs data exists" do
      artist_info =
        artist_info_fixture(%{
          musicbrainz_data: %{"name" => "No Image Artist"},
          discogs_data: nil
        })

      assert {:cancel, :no_discogs_data} =
               perform_job(FetchArtistImage, %{"id" => artist_info.id})
    end

    test "cancels when discogs data has no images" do
      artist_info =
        artist_info_fixture(%{
          musicbrainz_data: %{"name" => "No Image Artist"},
          discogs_data: %{"id" => 12_345, "images" => []}
        })

      assert {:cancel, :image_not_found} =
               perform_job(FetchArtistImage, %{"id" => artist_info.id})
    end
  end
end
