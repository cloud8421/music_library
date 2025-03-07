defmodule MusicLibraryWeb.CollectionLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicBrainz.Fixtures.Release
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]
  alias MusicBrainz.ReleaseGroupSearchResult
  alias MusicLibrary.Records.{Cover, Record}

  @default_records_page_size 20
  @total_records @default_records_page_size + 10

  defp fill_collection(_) do
    records = Enum.map(1..@total_records, fn _ -> record() end)
    %{collection: records}
  end

  defp fill_wishlist(_) do
    records = Enum.map(1..@total_records, fn _ -> record(%{purchased_at: nil}) end)
    %{wishlist: records}
  end

  describe "Collection" do
    setup [:fill_collection, :fill_wishlist]

    test "does not show wishlist records", %{
      conn: conn,
      wishlist: wishlist_records
    } do
      session = visit(conn, ~p"/collection")

      for record <- wishlist_records do
        refute_has(session, "#records-#{record.id}")
      end
    end

    test "shows purchased records (first page only)", %{conn: conn} do
      # We fetch collection records to maintain consistent order
      records = MusicLibrary.Collection.search_records("")

      {expected_present, expected_absent} = Enum.split(records, @default_records_page_size)

      session = visit(conn, ~p"/collection")

      for record <- expected_present do
        cover_url = ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"

        session
        |> assert_has("#records-#{record.id}")
        |> assert_has("#records-#{record.id} h2", text: escape(record.title))
        |> assert_has("#records-#{record.id} p", text: record.release)
        |> assert_has("#records-#{record.id} p", text: format_label(record.format))
        |> assert_has("#records-#{record.id} p", text: type_label(record.type))
        |> assert_has("#records-#{record.id} span",
          text: Record.format_as_date(record.purchased_at)
        )
        |> assert_has("img[src='#{cover_url}']")

        for artist <- record.artists do
          assert_has(session, "#records-#{record.id} a", text: escape(artist.name))
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
      page_size = 10

      {page_1_records, rest_of_records} = Enum.split(records, page_size)
      {page_2_records, rest_of_records} = Enum.split(rest_of_records, page_size)

      page_2_session =
        visit(conn, ~p"/collection?page=2&page_size=#{page_size}")

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
      |> assert_has("#bottom_pagination a", text: "1")
      |> refute_has("#bottom_pagination a", text: "2")
      |> assert_has("#bottom_pagination a", text: "3")

      {page_3_records, rest_of_records} = Enum.split(rest_of_records, page_size)

      page_3_session =
        visit(conn, ~p"/collection?page=3&page_size=#{page_size}")

      for record <- page_3_records do
        assert_has(page_3_session, "#records-#{record.id}")
      end

      for record <- rest_of_records do
        refute_has(page_3_session, "#records-#{record.id}")
      end

      page_3_session
      |> assert_has("#bottom_pagination a", text: "1")
      |> assert_has("#bottom_pagination a", text: "2")
      |> refute_has("#bottom_pagination a", text: "3")
    end
  end

  describe "Tagged search" do
    setup [:fill_collection]

    test "supports raw queries", %{conn: conn, collection: records} do
      [record | _rest] = records
      qs = [query: record.title]

      session =
        visit(conn, ~p"/collection?#{qs}")

      cover_url = ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"

      session
      |> assert_has("#records-#{record.id}")
      |> assert_has("#records-#{record.id} h2", text: escape(record.title))
      |> assert_has("#records-#{record.id} p", text: record.release)
      |> assert_has("#records-#{record.id} p", text: format_label(record.format))
      |> assert_has("#records-#{record.id} p", text: type_label(record.type))
      |> assert_has("#records-#{record.id} span",
        text: Record.format_as_date(record.purchased_at)
      )
      |> assert_has("img[src='#{cover_url}']")

      for artist <- record.artists do
        assert_has(session, "#records-#{record.id} a", text: escape(artist.name))
      end
    end

    test "supports filters", %{conn: conn, collection: records} do
      {artist_with_most_records, _records_count} =
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
        page_size: @default_records_page_size
      ]

      session =
        visit(conn, ~p"/collection?#{qs}")

      for record <- present do
        cover_url = ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"

        session
        |> assert_has("#records-#{record.id}")
        |> assert_has("#records-#{record.id} h2", text: escape(record.title))
        |> assert_has("#records-#{record.id} p", text: record.release)
        |> assert_has("#records-#{record.id} p", text: format_label(record.format))
        |> assert_has("#records-#{record.id} p", text: type_label(record.type))
        |> assert_has("#records-#{record.id} span",
          text: Record.format_as_date(record.purchased_at)
        )
        |> assert_has("img[src='#{cover_url}']")

        for artist <- record.artists do
          assert_has(session, "#records-#{record.id} a", text: escape(artist.name))
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
      |> assert_has("h2", text: escape(record.title))
      |> assert_path(~p"/collection/#{record}/edit")
    end

    test "can change the record cover", %{conn: conn} do
      record = record(cover_data: File.read!(marbles_cover_fixture()))
      cover_url = ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"

      session =
        conn
        |> visit(~p"/collection/#{record.id}/edit")
        |> assert_has("img[src='#{cover_url}']")

      session =
        session
        |> upload("Cover art", raven_cover_fixture())
        |> click_button("Save")
        |> assert_has("p", text: "Record updated successfully")

      updated_cover = MusicLibrary.Records.get_cover(record.id)
      updated_cover_url = ~p"/covers/#{record.id}?vsn=#{updated_cover.cover_hash}"

      assert updated_cover.cover_hash !== record.cover_hash
      assert_has(session, "img[src='#{updated_cover_url}']")
    end
  end

  describe "Importing a new record" do
    test "it shows the import modal", %{conn: conn} do
      conn
      |> visit(~p"/collection")
      |> click_link("Import")
      |> assert_has("label", text: "Search for a record on MusicBrainz")
      |> assert_has("div", text: "No results")
      |> assert_path(~p"/collection/import")
    end

    test "it imports a record when selected", %{conn: conn} do
      release_group_search_results = Map.get(release_group_search_results(), "release-groups")

      first_release_group_search_result = hd(release_group_search_results)
      first_release_group_search_result_id = first_release_group_search_result["id"]

      release_group = release_group(:marbles)
      release_group_releases = release_group_releases(:marbles)

      cover_data = File.read!(marbles_cover_fixture())

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
        |> fill_in("Search for a record on MusicBrainz", with: "Marillion Marbles")

      for release_group_search_result <- release_group_search_results do
        result = ReleaseGroupSearchResult.from_api_response(release_group_search_result)

        session
        |> assert_has("h1", text: result.artists)
        |> assert_has("h2", text: result.title)
        |> assert_has("p", text: Record.format_release(result.release))
      end

      session =
        session
        |> click_link("#musicbrainz_#{first_release_group_search_result_id} a", "CD")

      [record] = MusicLibrary.Repo.all(MusicLibrary.Records.Record)

      assert record.musicbrainz_id == first_release_group_search_result_id
      assert record.title == "Marbles"
      assert record.release == "2004-05-03"
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
               "0ED79C93C5BECC7B28FE05CAA3E49B924A3377EA3219CA8FFAE3B2B0960F2AC8"

      {:ok, resized_cover_data} = Cover.resize(cover_data)

      assert record.cover_data == resized_cover_data

      assert record.inserted_at !== nil
      assert record.updated_at !== nil
      assert record.purchased_at !== nil

      [marillion] = record.artists

      assert %MusicLibrary.Records.Artist{
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
        |> assert_has("h1", text: "Scan one or more barcodes")
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

    cover_data = File.read!(marbles_cover_fixture())

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
    |> assert_has("h2", text: "Marbles")
    |> assert_has("span", text: "New")
    |> click_button("Import releases")

    [record] = MusicLibrary.Repo.all(MusicLibrary.Records.Record)

    assert record.musicbrainz_id == release_group_id
    assert record.title == "Marbles"
    assert record.release == "2004-05-03"
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
             "0ED79C93C5BECC7B28FE05CAA3E49B924A3377EA3219CA8FFAE3B2B0960F2AC8"

    {:ok, resized_cover_data} = Cover.resize(cover_data)

    assert record.cover_data == resized_cover_data

    assert record.inserted_at !== nil
    assert record.updated_at !== nil
    assert record.purchased_at !== nil

    [marillion] = record.artists

    assert %MusicLibrary.Records.Artist{
             name: "Marillion",
             sort_name: "Marillion",
             disambiguation: "British progressive rock band",
             musicbrainz_id: "1932f5b6-0b7b-4050-b1df-833ca89e5f44"
           } = marillion
  end
end
