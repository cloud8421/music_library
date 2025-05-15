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

    test "it shows the artist bio and play count", %{
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
      |> assert_has("span", text: "123")
      |> assert_has("summary", text: "Biography")
      |> assert_has("details")
    end

    test "it gracefully handles errors in fetching bio and play count", %{
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
      |> refute_has("span", text: "123")
      |> refute_has("summary", text: "Biography")
      |> assert_has("div", text: "Error loading play count")
      |> assert_has("div", text: "Error loading biography")
    end

    test "it shows the artist country and MB id", %{
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
      |> assert_has("span", text: "United Kingdom")
      |> assert_has("span", text: "🇬🇧")
      |> assert_has("dd", text: artist_musicbrainz_id)
    end

    test "it shows records from the collection and the wishlist", %{
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
      |> assert_has("#collection p", text: escape(collection_record.title))
      |> assert_has("#wishlist p", text: escape(wishlist_record.title))
      |> refute_has("#collection p", text: escape(other_collection_record.title))
      |> refute_has("#wishlist p", text: escape(other_collection_record.title))
    end
  end
end
