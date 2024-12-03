defmodule MusicLibraryWeb.ArtistLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest
  import MusicLibrary.RecordsFixtures
  import LastFm.Fixtures
  import Mox

  alias LastFm.{Artist, APIBehaviourMock}

  setup :verify_on_exit!

  describe "Show artist" do
    test "it shows records from the collection", %{conn: conn} do
      current_time = DateTime.utc_now()

      collection_record =
        record_fixture_with_artist("Steven Wilson", %{purchased_at: current_time})

      _wishlist_record = record_fixture_with_artist("Steven Wilson", %{purchased_at: nil})
      _other_record = record_fixture_with_artist("Porcupine Tree", %{purchased_at: current_time})

      [artist] = collection_record.artists
      artist_musicbrainz_id = artist.musicbrainz_id

      expect(APIBehaviourMock, :get_artist_info, fn ^artist_musicbrainz_id, _config ->
        {:ok,
         artist_get_info()
         |> Map.get("artist")
         |> Artist.from_api_response()}
      end)

      {:ok, show_live, _html} = live(conn, ~p"/artists/#{artist_musicbrainz_id}")

      assert render_async(show_live) =~ "Steven Wilson"
    end
  end
end
