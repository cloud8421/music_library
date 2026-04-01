defmodule MusicLibrary.Worker.FetchArtistInfoTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Artists
  alias MusicLibrary.Worker.FetchArtistInfo

  # The MusicBrainz fixture for Steven Wilson uses this fixed ID
  @steven_wilson_mbid "3a51b862-0144-40f6-aa17-6aaeefea29d9"

  describe "perform/1" do
    test "discards when artist has no English Wikipedia page" do
      _record =
        record(%{
          artists: [
            %{
              name: "Steven Wilson",
              musicbrainz_id: @steven_wilson_mbid,
              sort_name: "Wilson, Steven",
              joinphrase: ""
            }
          ]
        })

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, MusicBrainz.Fixtures.Artist.get_artist())
      end)

      Req.Test.stub(Discogs.API, fn conn ->
        case conn.request_path do
          "/artists/" <> _ ->
            Req.Test.json(conn, Discogs.Fixtures.Artist.get_artist())

          _ ->
            Plug.Conn.send_resp(conn, 200, Discogs.Fixtures.Artist.image_data())
        end
      end)

      Req.Test.stub(Wikipedia.API, fn conn ->
        Req.Test.json(conn, Wikipedia.Fixtures.wikidata_response_no_enwiki())
      end)

      assert {:discard, :no_english_wikipedia} =
               perform_job(FetchArtistInfo, %{"id" => @steven_wilson_mbid})
    end

    test "fetches and stores artist info from all sources" do
      # Create a record with the artist musicbrainz_id matching the fixture
      _record =
        record(%{
          artists: [
            %{
              name: "Steven Wilson",
              musicbrainz_id: @steven_wilson_mbid,
              sort_name: "Wilson, Steven",
              joinphrase: ""
            }
          ]
        })

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, MusicBrainz.Fixtures.Artist.get_artist())
      end)

      Req.Test.stub(Discogs.API, fn conn ->
        case conn.request_path do
          "/artists/" <> _ ->
            Req.Test.json(conn, Discogs.Fixtures.Artist.get_artist())

          _ ->
            Plug.Conn.send_resp(conn, 200, Discogs.Fixtures.Artist.image_data())
        end
      end)

      Req.Test.stub(Wikipedia.API, fn conn ->
        conn = Plug.Conn.fetch_query_params(conn)

        case conn.params do
          %{"action" => "wbgetentities"} ->
            Req.Test.json(conn, Wikipedia.Fixtures.wikidata_response())

          %{"action" => "query"} ->
            Req.Test.json(conn, Wikipedia.Fixtures.article_extract())

          _ ->
            Req.Test.json(conn, Wikipedia.Fixtures.article_summary())
        end
      end)

      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, %{
          "toptags" => %{
            "tag" => [
              %{"name" => "progressive rock", "count" => 100}
            ]
          }
        })
      end)

      assert :ok = perform_job(FetchArtistInfo, %{"id" => @steven_wilson_mbid})

      artist_info = Artists.get_artist_info!(@steven_wilson_mbid)
      assert artist_info.musicbrainz_data != nil
      assert artist_info.wikipedia_data != nil
    end
  end
end
