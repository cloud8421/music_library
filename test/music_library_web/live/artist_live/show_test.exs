defmodule MusicLibraryWeb.ArtistLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records

  alias LastFm.Fixtures

  defp fill_collection(_config) do
    collection_record =
      record_with_artist("Steven Wilson", %{
        title: "The Raven that refused to sing",
        purchased_at: DateTime.utc_now()
      })

    [artist] = collection_record.artists

    artist_info = artist_info(artist.musicbrainz_id)

    %{
      collection_record: collection_record,
      artist_musicbrainz_id: artist.musicbrainz_id,
      artist_info: artist_info
    }
  end

  describe "Show artist" do
    setup :fill_collection

    test "shows the artist bio and play count", %{
      conn: conn,
      artist_musicbrainz_id: artist_musicbrainz_id
    } do
      Req.Test.stub(LastFm.API, fn conn ->
        case Map.get(conn.params, "method") do
          "artist.getInfo" ->
            Req.Test.json(conn, Fixtures.Artist.get_info())

          "artist.getSimilar" ->
            Req.Test.json(conn, Fixtures.Artist.get_similar_artists())
        end
      end)

      conn
      |> visit(~p"/artists/#{artist_musicbrainz_id}")
      |> unwrap(&render_async/1)
      |> assert_has("span", "No scrobbles")
      |> assert_has("dt", "Biography")
    end

    test "renders the Wikipedia biography in the bio sheet", %{
      conn: conn,
      artist_musicbrainz_id: artist_musicbrainz_id,
      artist_info: artist_info
    } do
      artist_info
      |> Ecto.Changeset.change(wikipedia_data: Wikipedia.Fixtures.article_summary())
      |> MusicLibrary.Repo.update!()

      Req.Test.stub(LastFm.API, fn conn ->
        case Map.get(conn.params, "method") do
          "artist.getInfo" ->
            Req.Test.json(conn, Fixtures.Artist.get_info())

          "artist.getSimilar" ->
            Req.Test.json(conn, Fixtures.Artist.get_similar_artists())
        end
      end)

      conn
      |> visit(~p"/artists/#{artist_musicbrainz_id}")
      |> unwrap(&render_async/1)
      |> assert_has("dt", "Biography")
      |> assert_has("span", "Wikipedia")
      |> assert_has("p", text: "English musician")
    end

    test "gracefully handles errors in fetching bio and play count", %{
      conn: conn,
      artist_musicbrainz_id: artist_musicbrainz_id
    } do
      Req.Test.stub(LastFm.API, fn conn ->
        case Map.get(conn.params, "method") do
          "artist.getInfo" ->
            Req.Test.transport_error(conn, :timeout)

          "artist.getSimilar" ->
            Req.Test.json(conn, Fixtures.Artist.get_similar_artists())
        end
      end)

      conn
      |> visit(~p"/artists/#{artist_musicbrainz_id}")
      |> unwrap(&render_async/1)
      |> assert_has("span", "No scrobbles")
      |> refute_has("summary", "Biography")
      |> assert_has("div", "Error loading biography")
    end

    test "shows the artist country and MB id", %{
      conn: conn,
      artist_musicbrainz_id: artist_musicbrainz_id
    } do
      Req.Test.stub(LastFm.API, fn conn ->
        case Map.get(conn.params, "method") do
          "artist.getInfo" ->
            Req.Test.json(conn, Fixtures.Artist.get_info())

          "artist.getSimilar" ->
            Req.Test.json(conn, Fixtures.Artist.get_similar_artists())
        end
      end)

      conn
      |> visit(~p"/artists/#{artist_musicbrainz_id}")
      |> unwrap(&render_async/1)
      |> assert_has("span", "United Kingdom")
      |> assert_has("span", "🇬🇧")
      |> assert_has("code", artist_musicbrainz_id)
    end

    test "shows records from the collection and the wishlist", %{
      conn: conn,
      collection_record: collection_record,
      artist_musicbrainz_id: artist_musicbrainz_id
    } do
      wishlist_record =
        record_with_artist("Steven Wilson", %{
          title: "Grace for drowning",
          purchased_at: nil
        })

      other_collection_record =
        record_with_artist("Porcupine Tree", %{purchased_at: DateTime.utc_now()})

      Req.Test.stub(LastFm.API, fn conn ->
        case Map.get(conn.params, "method") do
          "artist.getInfo" ->
            Req.Test.json(conn, Fixtures.Artist.get_info())

          "artist.getSimilar" ->
            Req.Test.json(conn, Fixtures.Artist.get_similar_artists())
        end
      end)

      conn
      |> visit(~p"/artists/#{artist_musicbrainz_id}")
      |> unwrap(&render_async/1)
      |> assert_has("#collection p", escape(collection_record.title))
      |> assert_has("#wishlist p", escape(wishlist_record.title))
      |> refute_has("#collection p", escape(other_collection_record.title))
      |> refute_has("#wishlist p", escape(other_collection_record.title))
    end
  end
end
