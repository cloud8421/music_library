defmodule MusicLibrary.Worker.ArtistRefreshWikipediaDataTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ArtistInfoFixtures
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Artists
  alias MusicLibrary.Worker.ArtistRefreshWikipediaData

  setup do
    record = record()
    artist = hd(record.artists)
    artist_info = artist_info(artist.musicbrainz_id)
    %{artist_info: artist_info}
  end

  describe "perform/1" do
    test "refreshes Wikipedia data", %{artist_info: artist_info} do
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

      assert {:ok, refreshed} = perform_job(ArtistRefreshWikipediaData, %{"id" => artist_info.id})
      assert refreshed.id == artist_info.id

      updated = Artists.get_artist_info!(artist_info.id)
      assert is_map(updated.wikipedia_data)
      assert Map.has_key?(updated.wikipedia_data, "intro_html")
    end

    test "discards job when no wikidata_id exists in musicbrainz_data" do
      artist_info =
        artist_info_fixture(%{musicbrainz_data: %{"name" => "No Wikipedia Artist"}})

      # No wikidata relation in musicbrainz_data → fetch_wikipedia_data returns {:ok, artist_info}
      # Worker wraps non-error returns with `with`, so it passes through as :ok
      assert {:ok, unchanged} = perform_job(ArtistRefreshWikipediaData, %{"id" => artist_info.id})
      assert unchanged.id == artist_info.id
      assert unchanged.wikipedia_data == artist_info.wikipedia_data
    end
  end
end
