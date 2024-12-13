defmodule MusicLibraryWeb.ArtistLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest
  import MusicLibrary.RecordsFixtures
  import LastFm.Fixtures
  import Mox

  alias LastFm.{Artist, APIBehaviourMock}

  setup :verify_on_exit!

  defp escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  describe "Show artist" do
    test "it shows the artist bio and play count", %{conn: conn} do
      current_time = DateTime.utc_now()

      collection_record =
        record_fixture_with_artist("Steven Wilson", %{purchased_at: current_time})

      [artist] = collection_record.artists
      artist_musicbrainz_id = artist.musicbrainz_id

      expect(APIBehaviourMock, :get_artist_info, fn {:musicbrainz_id, ^artist_musicbrainz_id},
                                                    _config ->
        {:ok,
         artist_get_info()
         |> Map.get("artist")
         |> Artist.from_api_response()}
      end)

      {:ok, show_live, _html} = live(conn, ~p"/artists/#{artist_musicbrainz_id}")

      render_async(show_live)

      # play count
      assert has_element?(show_live, "span", "123")

      assert has_element?(show_live, "summary", "Biography")

      assert element(show_live, "details")
    end

    test "it gracefully handles errors in fetching bio and play count", %{conn: conn} do
      current_time = DateTime.utc_now()

      collection_record =
        record_fixture_with_artist("Steven Wilson", %{purchased_at: current_time})

      [artist] = collection_record.artists
      artist_musicbrainz_id = artist.musicbrainz_id

      expect(APIBehaviourMock, :get_artist_info, fn {:musicbrainz_id, ^artist_musicbrainz_id},
                                                    _config ->
        {:error, :timeout}
      end)

      {:ok, show_live, _html} = live(conn, ~p"/artists/#{artist_musicbrainz_id}")

      render_async(show_live)

      # play count
      refute has_element?(show_live, "span", "123")
      assert has_element?(show_live, "div", "There was an error loading the play count")

      refute has_element?(show_live, "summary", "Biography")
      assert has_element?(show_live, "div", "There was an error loading the biography")
    end

    test "it shows records from the collection and the wishlist", %{conn: conn} do
      current_time = DateTime.utc_now()

      collection_record =
        record_fixture_with_artist("Steven Wilson", %{
          title: "The Raven that refused to sing",
          purchased_at: current_time
        })

      wishlist_record =
        record_fixture_with_artist("Steven Wilson", %{
          title: "Grace for drowning",
          purchased_at: nil
        })

      other_record = record_fixture_with_artist("Porcupine Tree", %{purchased_at: current_time})

      [artist] = collection_record.artists
      artist_musicbrainz_id = artist.musicbrainz_id

      {:ok, show_live, _html} = live(conn, ~p"/artists/#{artist_musicbrainz_id}")

      # collection records
      assert has_element?(show_live, "#collection p", escape(collection_record.title))

      # wishlist records
      assert has_element?(show_live, "#wishlist p", escape(wishlist_record.title))

      # other records
      refute has_element?(show_live, "#collection p", escape(other_record.title))
      refute has_element?(show_live, "#wishlist p", escape(other_record.title))
    end
  end
end
