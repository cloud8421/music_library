defmodule MusicLibrary.Worker.FetchArtistLastFmDataTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ArtistInfoFixtures

  alias MusicLibrary.Artists
  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Worker.FetchArtistLastFmData

  setup do
    artist_info =
      artist_info_fixture(%{musicbrainz_data: %{"name" => "Steven Wilson"}})

    %{artist_id: artist_info.id}
  end

  describe "perform/1" do
    test "stores Last.fm tags in lastfm_data", %{artist_id: artist_id} do
      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, %{
          "toptags" => %{
            "tag" => [
              %{"name" => "progressive rock", "count" => 100},
              %{"name" => "art rock", "count" => 80},
              %{"name" => "psychedelic", "count" => 60}
            ]
          }
        })
      end)

      assert :ok = perform_job(FetchArtistLastFmData, %{"id" => artist_id})

      artist_info = Artists.get_artist_info!(artist_id)
      tags = ArtistInfo.lastfm_tags(artist_info)

      assert "progressive rock" in tags
      assert "art rock" in tags
      assert "psychedelic" in tags
    end

    @tag :capture_log
    test "returns error when Last.fm returns an error", %{artist_id: artist_id} do
      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, %{"error" => 6, "message" => "Artist not found"})
      end)

      assert {:error, :invalid_parameters} ==
               perform_job(FetchArtistLastFmData, %{"id" => artist_id})
    end

    test "filters out tags with count below 2", %{artist_id: artist_id} do
      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, %{
          "toptags" => %{
            "tag" => [
              %{"name" => "progressive rock", "count" => 50},
              %{"name" => "rare tag", "count" => 1},
              %{"name" => "another rare", "count" => 0}
            ]
          }
        })
      end)

      assert :ok = perform_job(FetchArtistLastFmData, %{"id" => artist_id})

      artist_info = Artists.get_artist_info!(artist_id)
      tags = ArtistInfo.lastfm_tags(artist_info)

      assert "progressive rock" in tags
      refute "rare tag" in tags
      refute "another rare" in tags
    end
  end
end
