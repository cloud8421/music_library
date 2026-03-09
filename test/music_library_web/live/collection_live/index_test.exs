defmodule MusicLibraryWeb.CollectionLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias MusicBrainz.ReleaseGroupSearchResult
  alias MusicLibrary.Assets
  alias MusicLibrary.Assets.{Image, Transform}
  alias MusicLibrary.Records.Record

  # make it a multiple of 4 for easier calculations
  @default_records_page_size 4
  @total_records @default_records_page_size + div(@default_records_page_size, 2)

  defp fill_collection(_) do
    records = Enum.map(1..@total_records, fn _ -> record() end)
    %{collection: records}
  end

  describe "Collection" do
    setup [:fill_collection]

    test "does not show wishlist records", %{conn: conn} do
      wishlist_records = Enum.map(1..3, fn _ -> record(%{purchased_at: nil}) end)
      session = visit(conn, ~p"/collection")

      for record <- wishlist_records do
        refute_has(session, "#records-#{record.id}")
      end
    end

    test "shows purchased records (first page only)", %{conn: conn} do
      limit = div(@default_records_page_size, 2)
      page_size = div(@default_records_page_size, 4)

      records =
        MusicLibrary.Collection.search_records("", limit: limit)

      {expected_present, expected_absent} =
        Enum.split(records, page_size)

      session =
        conn
        |> visit(~p"/collection?order=alphabetical&page_size=#{page_size}")
        |> click_button("List")

      for record <- expected_present do
        cover_url = cover_url(record, 160)

        session
        |> assert_has("#records-#{record.id}")
        |> assert_has("#records-#{record.id} h2", escape(record.title))
        |> assert_has("#records-#{record.id} p", record.release_date)
        |> assert_has("#records-#{record.id} p", format_label(record.format))
        |> assert_has("#records-#{record.id} p", type_label(record.type))
        |> assert_has("#records-#{record.id} span",
          text: Record.format_as_date(record.purchased_at)
        )
        |> assert_has("img[src='#{cover_url}']")

        for artist <- record.artists do
          assert_has(session, "#records-#{record.id} a", escape(artist.name))
        end
      end

      for record <- expected_absent do
        refute_has(session, "#records-#{record.id}")
      end
    end
  end

  describe "Search and pagination" do
    setup [:fill_collection]

    test "uses query string params", %{conn: conn} do
      # We fetch collection records to maintain consistent order
      records = MusicLibrary.Collection.search_records("")
      page_size = div(@default_records_page_size, 4)

      {page_1_records, rest_of_records} = Enum.split(records, page_size)
      {page_2_records, rest_of_records} = Enum.split(rest_of_records, page_size)

      page_2_session =
        visit(conn, ~p"/collection?order=alphabetical&page=2&page_size=#{page_size}")

      for record <- page_1_records do
        refute_has(page_2_session, "#records-#{record.id}")
      end

      for record <- page_2_records do
        assert_has(page_2_session, "#records-#{record.id}")
      end

      for record <- rest_of_records do
        refute_has(page_2_session, "#records-#{record.id}")
      end

      page_2_session
      |> assert_has("#bottom_pagination a", "1")
      |> refute_has("#bottom_pagination a", "2")
      |> assert_has("#bottom_pagination a", "3")

      {page_3_records, rest_of_records} = Enum.split(rest_of_records, page_size)

      # Safeguard - make sure we're not testing against empty lists
      refute Enum.empty?(page_3_records)
      refute Enum.empty?(rest_of_records)

      page_3_session =
        visit(conn, ~p"/collection?order=alphabetical&page=3&page_size=#{page_size}")

      for record <- page_3_records do
        assert_has(page_3_session, "#records-#{record.id}")
      end

      for record <- rest_of_records do
        refute_has(page_3_session, "#records-#{record.id}")
      end

      page_3_session
      |> assert_has("#bottom_pagination a", "1")
      |> assert_has("#bottom_pagination a", "2")
      |> refute_has("#bottom_pagination a", "3")
    end
  end

  describe "Tagged search" do
    setup [:fill_collection]

    test "supports raw queries", %{conn: conn, collection: records} do
      [record | _rest] = records
      qs = [query: record.title]

      session =
        conn
        |> visit(~p"/collection?#{qs}")
        |> click_button("List")

      cover_url = cover_url(record, 160)

      session
      |> assert_has("#records-#{record.id}")
      |> assert_has("#records-#{record.id} h2", escape(record.title))
      |> assert_has("#records-#{record.id} p", record.release_date)
      |> assert_has("#records-#{record.id} p", format_label(record.format))
      |> assert_has("#records-#{record.id} p", type_label(record.type))
      |> assert_has("#records-#{record.id} span",
        text: Record.format_as_date(record.purchased_at)
      )
      |> assert_has("img[src='#{cover_url}']")

      for artist <- record.artists do
        assert_has(session, "#records-#{record.id} a", escape(artist.name))
      end
    end

    test "supports filters", %{conn: conn, collection: records} do
      {artist_with_most_records, records_count} =
        records
        |> Enum.frequencies_by(fn r ->
          [artist] = r.artists
          artist.name
        end)
        |> Enum.max_by(fn {_artist, count} -> count end)

      {present, absent} =
        Enum.split_with(records, fn r ->
          [artist] = r.artists
          artist.name == artist_with_most_records
        end)

      qs = [
        query: ~s(artist:"#{artist_with_most_records}"),
        # Sometimes we generate more reconrds than the default page size, so we
        # need to make sure all of them are included in the results
        page_size: max(@default_records_page_size, records_count)
      ]

      session =
        conn
        |> visit(~p"/collection?#{qs}")
        |> click_button("List")

      for record <- present do
        cover_url = cover_url(record, 160)

        session
        |> assert_has("#records-#{record.id}")
        |> assert_has("#records-#{record.id} h2", escape(record.title))
        |> assert_has("#records-#{record.id} p", record.release_date)
        |> assert_has("#records-#{record.id} p", format_label(record.format))
        |> assert_has("#records-#{record.id} p", type_label(record.type))
        |> assert_has("#records-#{record.id} span",
          text: Record.format_as_date(record.purchased_at)
        )
        |> assert_has("img[src='#{cover_url}']")

        for artist <- record.artists do
          assert_has(session, "#records-#{record.id} a", escape(artist.name))
        end
      end

      for record <- absent do
        refute_has(session, "#records-#{record.id}")
      end
    end
  end

  describe "Updating record metadata" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record()

      conn
      |> visit(~p"/collection")
      |> click_link("#records-#{record.id} a", "Edit")
      |> assert_has("h2", escape(record.title))
      |> assert_path(~p"/collection/#{record}/edit")
    end

    test "can change the record cover", %{conn: conn} do
      record = record()
      cover_url = cover_url(record, nil)

      session =
        conn
        |> visit(~p"/collection/#{record.id}/edit")
        |> assert_has("img[src='#{cover_url}']")

      session =
        session
        |> upload("Cover art", raven_cover_fixture())
        |> click_button("Save")
        |> assert_has("p", "Record updated successfully")

      updated_record = MusicLibrary.Records.get_record!(record.id)
      updated_cover_url = cover_url(updated_record, 460)

      assert updated_record.cover_hash !== record.cover_hash
      assert_has(session, "img[src='#{updated_cover_url}']")
    end
  end

  describe "Adding a new record" do
    test "it shows the import modal", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> click_link("Add")
      |> assert_has("label", "Search for a record")
      |> assert_has("div", "No results")
      |> assert_path(~p"/collection/import")
    end

    test "it imports a record when selected", %{conn: conn} do
      release_group_search_results = Map.get(release_group_search_results(), "release-groups")

      first_release_group_search_result = hd(release_group_search_results)
      first_release_group_search_result_id = first_release_group_search_result["id"]

      release_group = release_group(:marbles)
      release_group_releases = release_group_releases(:marbles)

      cover_data = marbles_cover_data()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^first_release_group_search_result_id] ->
            Req.Test.json(conn, release_group)

          [_ws, _version, "release-group"] ->
            Req.Test.json(conn, release_group_search_results())

          [_ws, _version, "release"] ->
            Req.Test.json(conn, release_group_releases)

          [_release_group, ^first_release_group_search_result_id, "front"] ->
            Plug.Conn.send_resp(conn, 200, cover_data)
        end
      end)

      session =
        conn
        |> visit(~p"/collection/import")
        |> fill_in("Search for a record", with: "Marillion Marbles")

      for release_group_search_result <- release_group_search_results do
        result = ReleaseGroupSearchResult.from_api_response(release_group_search_result)

        session
        |> assert_has("h1", result.artists)
        |> assert_has("h2", result.title)
        |> assert_has("p", Record.format_release_date(result.release_date))
      end

      session =
        session
        |> click_link("#musicbrainz_#{first_release_group_search_result_id} a", "CD")

      [record] = MusicLibrary.Repo.all(MusicLibrary.Records.Record)

      assert record.musicbrainz_id == first_release_group_search_result_id
      assert record.title == "Marbles"
      assert record.release_date == "2004-05-03"
      assert record.format == :cd
      assert record.musicbrainz_data == release_group

      assert record.genres == [
               "alternative rock",
               "art rock",
               "baroque pop",
               "pop rock",
               "progressive rock",
               "psychedelic pop",
               "rock"
             ]

      assert record.cover_hash ==
               "E7238C742E5B8711FC5BFF01A4A1F727D9E404A4D1420429A6B37ABFFC0B5960"

      {:ok, resized_cover_data} = Image.resize(cover_data)

      assets = Assets.get(record.cover_hash)

      assert assets.content == resized_cover_data

      assert record.inserted_at !== nil
      assert record.updated_at !== nil
      assert record.purchased_at !== nil

      [marillion] = record.artists

      assert %MusicLibrary.Artists.Artist{
               name: "Marillion",
               sort_name: "Marillion",
               disambiguation: "British progressive rock band",
               musicbrainz_id: "1932f5b6-0b7b-4050-b1df-833ca89e5f44"
             } = marillion

      assert_path(session, ~p"/collection/#{record.id}")
    end
  end

  describe "Add via barcode scan" do
    test "it tracks the camera status", %{conn: conn} do
      session =
        conn
        |> visit(~p"/collection/scan")
        |> assert_has("h1", "Scan one or more barcodes")
        |> assert_has("button#camera-button")

      session
      |> trigger_hook("#barcode-scanner", "camera_denied")
      |> assert_has("button#camera-button")
      |> refute_has("video#camera-preview")

      session
      |> trigger_hook("#barcode-scanner", "camera_allowed")
      |> refute_has("button#camera-button")
      |> assert_has("video#camera-preview")
    end
  end

  test "it adds a record after scanning", %{conn: conn} do
    barcode = "5037300650128"
    releases = releases(:marbles)

    release = release(:marbles)
    release_id = release_id(:marbles)

    release_group = release_group(:marbles)
    release_group_id = release_group["id"]
    release_group_releases = release_group_releases(:marbles)

    cover_data = marbles_cover_data()

    Req.Test.stub(MusicBrainz.API, fn conn ->
      case conn.path_info do
        [_ws, _version, "release-group", ^release_group_id] ->
          Req.Test.json(conn, release_group)

        [_ws, _version, "release", ^release_id] ->
          Req.Test.json(conn, release)

        [_ws, _version, "release"] ->
          if conn.params["query"] do
            # barcode scan
            Req.Test.json(conn, releases)
          else
            # Search by release group ID
            Req.Test.json(conn, release_group_releases)
          end

        [_release_group, ^release_group_id, "front"] ->
          Plug.Conn.send_resp(conn, 200, cover_data)
      end
    end)

    conn
    |> visit(~p"/collection/scan")
    |> trigger_hook("#barcode-scanner", "barcode_scanned", %{"number" => barcode})
    |> assert_has("h2", "Marbles")
    |> assert_has("span", "New")
    |> click_button("Add releases")

    [record] = MusicLibrary.Repo.all(MusicLibrary.Records.Record)

    assert record.musicbrainz_id == release_group_id
    assert record.title == "Marbles"
    assert record.release_date == "2004-05-03"
    assert record.format == :cd
    assert record.musicbrainz_data == release_group
    assert record.selected_release_id == "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608"

    assert record.genres == [
             "alternative rock",
             "art rock",
             "baroque pop",
             "pop rock",
             "progressive rock",
             "psychedelic pop",
             "rock"
           ]

    assert record.cover_hash ==
             "E7238C742E5B8711FC5BFF01A4A1F727D9E404A4D1420429A6B37ABFFC0B5960"

    asset = Assets.get(record.cover_hash)
    {:ok, resized_cover_data} = Image.resize(cover_data)

    assert asset.content == resized_cover_data

    assert record.inserted_at !== nil
    assert record.updated_at !== nil
    assert record.purchased_at !== nil

    [marillion] = record.artists

    assert %MusicLibrary.Artists.Artist{
             name: "Marillion",
             sort_name: "Marillion",
             disambiguation: "British progressive rock band",
             musicbrainz_id: "1932f5b6-0b7b-4050-b1df-833ca89e5f44"
           } = marillion
  end

  defp cover_url(record, width) do
    transform = %Transform{hash: record.cover_hash, width: width}
    payload = Transform.encode!(transform)
    ~p"/assets/#{payload}"
  end
end
