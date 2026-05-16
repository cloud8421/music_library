defmodule MusicLibraryWeb.ArtistLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records

  import Phoenix.LiveViewTest

  alias LastFm.Fixtures
  alias MusicLibrary.Artists
  alias MusicLibrary.Assets
  alias MusicLibrary.Assets.Asset
  alias Req.Test

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
      Test.stub(LastFm.API, fn conn ->
        case Map.get(conn.params, "method") do
          "artist.getInfo" ->
            Test.json(conn, Fixtures.Artist.get_info())

          "artist.getSimilar" ->
            Test.json(conn, Fixtures.Artist.get_similar_artists())
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

      Test.stub(LastFm.API, fn conn ->
        case Map.get(conn.params, "method") do
          "artist.getInfo" ->
            Test.json(conn, Fixtures.Artist.get_info())

          "artist.getSimilar" ->
            Test.json(conn, Fixtures.Artist.get_similar_artists())
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
      Test.stub(LastFm.API, fn conn ->
        case Map.get(conn.params, "method") do
          "artist.getInfo" ->
            Test.transport_error(conn, :timeout)

          "artist.getSimilar" ->
            Test.json(conn, Fixtures.Artist.get_similar_artists())
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
      Test.stub(LastFm.API, fn conn ->
        case Map.get(conn.params, "method") do
          "artist.getInfo" ->
            Test.json(conn, Fixtures.Artist.get_info())

          "artist.getSimilar" ->
            Test.json(conn, Fixtures.Artist.get_similar_artists())
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

      Test.stub(LastFm.API, fn conn ->
        case Map.get(conn.params, "method") do
          "artist.getInfo" ->
            Test.json(conn, Fixtures.Artist.get_info())

          "artist.getSimilar" ->
            Test.json(conn, Fixtures.Artist.get_similar_artists())
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

  describe "Edit artist image" do
    setup :fill_collection
    setup :stub_last_fm

    test "opens the edit modal with the form", %{
      conn: conn,
      artist_musicbrainz_id: musicbrainz_id
    } do
      conn
      |> visit(~p"/artists/#{musicbrainz_id}/edit")
      |> unwrap(&render_async/1)
      |> assert_has("#artist-info-form")
      |> assert_has("label", text: "Search for artist image online")
    end

    test "Brave Search displays image results", %{
      conn: conn,
      artist_musicbrainz_id: musicbrainz_id
    } do
      Test.stub(BraveSearch.API, fn conn ->
        assert conn.request_path == "/res/v1/images/search"
        Test.json(conn, BraveSearch.Fixtures.search_images_response())
      end)

      session =
        conn
        |> visit(~p"/artists/#{musicbrainz_id}/edit")
        |> unwrap(&render_async/1)
        |> click_button("#image-search-button", "Search")
        |> unwrap(&render_async/1)

      html = Phoenix.LiveViewTest.render(session.view)
      assert html =~ "https://thumbnails.example.com/raven-thumb.jpg"
    end

    @tag :capture_log
    test "Brave Search transport error surfaces a friendly message", %{
      conn: conn,
      artist_musicbrainz_id: musicbrainz_id
    } do
      Test.stub(BraveSearch.API, fn conn ->
        Test.transport_error(conn, :timeout)
      end)

      session =
        conn
        |> visit(~p"/artists/#{musicbrainz_id}/edit")
        |> unwrap(&render_async/1)
        |> click_button("#image-search-button", "Search")
        |> unwrap(&render_async/1)

      html = Phoenix.LiveViewTest.render(session.view)
      assert html =~ "Search failed"
    end

    test "uploading an image saves and updates the artist info", %{
      conn: conn,
      artist_musicbrainz_id: musicbrainz_id,
      artist_info: artist_info
    } do
      conn
      |> visit(~p"/artists/#{musicbrainz_id}/edit")
      |> unwrap(&render_async/1)
      |> unwrap(fn view ->
        image =
          file_input(view, "#artist-info-form", :image_data, [
            %{name: "raven.jpg", content: raven_cover_data(), type: "image/jpeg"}
          ])

        render_upload(image, "raven.jpg")

        view
        |> form("#artist-info-form")
        |> render_submit()
      end)

      updated = Artists.get_artist_info!(artist_info.id)
      assert updated.image_data_hash != artist_info.image_data_hash
      hash = updated.image_data_hash
      assert is_binary(hash) and byte_size(hash) > 0
      assert %Asset{hash: ^hash} = Assets.get(hash)
    end

    test "selecting a Brave Search result downloads and saves the image", %{
      conn: conn,
      artist_musicbrainz_id: musicbrainz_id,
      artist_info: artist_info
    } do
      raven_binary = raven_cover_data()

      Test.stub(BraveSearch.API, fn conn ->
        case conn.request_path do
          "/res/v1/images/search" ->
            Test.json(conn, BraveSearch.Fixtures.search_images_response())

          _ ->
            Plug.Conn.send_resp(conn, 200, raven_binary)
        end
      end)

      conn
      |> visit(~p"/artists/#{musicbrainz_id}/edit")
      |> unwrap(fn view -> render_async(view, 500) end)
      |> click_button("#image-search-button", "Search")
      |> unwrap(fn view -> render_async(view, 500) end)
      |> unwrap(fn view ->
        view
        |> element(
          "button[phx-click='select_image'][phx-value-url='https://images.example.com/raven-cover.jpg']"
        )
        |> render_click()
      end)
      |> unwrap(&render_async/1)

      updated = Artists.get_artist_info!(artist_info.id)
      assert updated.image_data_hash != artist_info.image_data_hash
      hash = updated.image_data_hash
      assert is_binary(hash) and byte_size(hash) > 0
      assert %Asset{hash: ^hash} = Assets.get(hash)
    end
  end

  defp stub_last_fm(_config) do
    Test.stub(LastFm.API, fn conn ->
      case Map.get(conn.params, "method") do
        "artist.getInfo" ->
          Test.json(conn, Fixtures.Artist.get_info())

        "artist.getSimilar" ->
          Test.json(conn, Fixtures.Artist.get_similar_artists())
      end
    end)

    :ok
  end
end
