defmodule MusicLibraryWeb.CollectionLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest
  import MusicLibrary.RecordsFixtures
  import MusicLibrary.ReleaseGroupsFixtures
  import Mox
  alias MusicLibrary.Records.{Cover, Record}
  alias MusicBrainz.APIBehaviourMock

  setup :verify_on_exit!

  @default_records_page_size 100
  @total_records @default_records_page_size + 10

  defp fill_collection(_) do
    records = Enum.map(1..@total_records, fn _ -> record_fixture() end)
    %{collection: records}
  end

  defp fill_wishlist(_) do
    records = Enum.map(1..@total_records, fn _ -> record_fixture(%{purchased_at: nil}) end)
    %{wishlist: records}
  end

  defp escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  describe "Collection" do
    setup [:fill_collection, :fill_wishlist]

    test "does not show wishlist records", %{
      conn: conn,
      wishlist: wishlist_records
    } do
      {:ok, index_live, _html} = live(conn, ~p"/collection")

      for record <- wishlist_records do
        refute has_element?(index_live, "#records-#{record.id}")
      end
    end

    test "shows purchased records", %{conn: conn, collection: records} do
      {:ok, index_live, html} = live(conn, ~p"/collection")

      assert html =~ "Collection"

      {present, absent} =
        Enum.split_with(records, fn record ->
          html =~ record.id
        end)

      assert length(present) == @default_records_page_size
      assert length(absent) == @total_records - @default_records_page_size

      for record <- present do
        record_row =
          index_live
          |> with_target("#records-#{record.id}")

        record_row_html = record_row |> render()

        assert record_row_html =~ escape(record.title)
        assert record_row_html =~ to_string(record.release)
        assert record_row_html =~ Record.format_long_label(record.format)
        assert record_row_html =~ Record.type_long_label(record.type)
        assert record_row_html =~ record.release
        assert record_row_html =~ ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"

        for artist <- record.artists do
          assert record_row_html =~ escape(artist.name)
        end
      end
    end
  end

  describe "Search and pagination" do
    setup [:fill_collection]

    test "uses query string params", %{conn: conn, collection: records} do
      {:ok, page_2_live, page_2_html} = live(conn, ~p"/collection?page=2&page_size=25")

      {page_2_present, page_2_absent} =
        Enum.split_with(records, fn record ->
          page_2_html =~ record.id
        end)

      assert length(page_2_present) == 25
      assert length(page_2_absent) == @total_records - 25

      page_2_pagination = page_2_live |> with_target("#pagination")
      refute has_element?(page_2_pagination, "a", "2")
      assert has_element?(page_2_pagination, "a", "1")
      assert has_element?(page_2_pagination, "a", "3")
      assert has_element?(page_2_pagination, "a", "4")
      assert has_element?(page_2_pagination, "a", "5")

      {:ok, page_3_live, page_3_html} = live(conn, ~p"/collection?page=3&page_size=25")

      {page_3_present, page_3_absent} =
        Enum.split_with(records, fn record ->
          page_3_html =~ record.id
        end)

      assert length(page_3_present) == 25
      assert length(page_3_absent) == @total_records - 25

      page_3_pagination = page_3_live |> with_target("#pagination")
      refute has_element?(page_3_pagination, "a", "3")
      assert has_element?(page_3_pagination, "a", "1")
      assert has_element?(page_3_pagination, "a", "2")
      assert has_element?(page_3_pagination, "a", "4")
      assert has_element?(page_3_pagination, "a", "5")

      # All records in page 3 were not present in page 2
      assert page_3_present -- page_2_absent == []
      # All records in page 2 are not present in page 3
      assert page_2_present -- page_3_absent == []
    end
  end

  describe "Tagged search" do
    setup [:fill_collection]

    test "supports raw queries", %{conn: conn, collection: records} do
      [record | _rest] = records
      qs = [query: record.title]
      {:ok, index_live, _html} = live(conn, ~p"/collection?#{qs}")

      record_row =
        index_live
        |> with_target("#records-#{record.id}")

      record_row_html = record_row |> render()

      assert record_row_html =~ escape(record.title)
      assert record_row_html =~ to_string(record.release)
      assert record_row_html =~ Record.format_long_label(record.format)
      assert record_row_html =~ Record.type_long_label(record.type)
      assert record_row_html =~ record.release
      assert record_row_html =~ ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"

      for artist <- record.artists do
        assert record_row_html =~ escape(artist.name)
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

      {:ok, index_live, _html} = live(conn, ~p"/collection?#{qs}")

      for record <- present do
        record_row =
          index_live
          |> with_target("#records-#{record.id}")

        record_row_html = record_row |> render()

        assert record_row_html =~ escape(record.title)
        assert record_row_html =~ to_string(record.release)
        assert record_row_html =~ Record.format_long_label(record.format)
        assert record_row_html =~ Record.type_long_label(record.type)
        assert record_row_html =~ record.release
        assert record_row_html =~ ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"

        for artist <- record.artists do
          assert record_row_html =~ escape(artist.name)
        end
      end

      for record <- absent do
        refute has_element?(index_live, "#records-#{record.id}")
      end
    end
  end

  describe "Updating record metadata" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record_fixture()

      {:ok, index_live, _html} = live(conn, ~p"/collection")

      assert index_live
             |> element("#records-#{record.id} a", "Edit")
             |> render_click() =~ "Edit"

      assert_patch(index_live, ~p"/collection/#{record}/edit")

      assert index_live |> render() =~ "Edit"
    end

    test "can change the record cover", %{conn: conn} do
      record = record_fixture(cover_data: File.read!(marbles_cover_fixture()))
      {:ok, form_live, html} = live(conn, ~p"/collection/#{record.id}/edit")

      assert html =~ ~p"/covers/#{record.id}?vsn=#{record.cover_hash}"

      cover_metadata = cover_metadata(raven_cover_fixture())

      cover_input = file_input(form_live, "#record-form", :cover_data, [cover_metadata])

      assert render_upload(cover_input, cover_metadata.name) =~ "100%"

      list_html = form_live |> element("#record-form") |> render_submit()

      assert list_html =~ "Record updated successfully"

      # We trigger another render to force the list view to update
      # and display the new cover
      list_html = form_live |> render()

      updated_cover = MusicLibrary.Records.get_cover(record.id)

      assert updated_cover.cover_hash !== record.cover_hash

      assert list_html =~ ~p"/covers/#{record.id}?vsn=#{updated_cover.cover_hash}"
    end

    defp cover_metadata(path) do
      stat = File.stat!(path)

      %{
        last_modified:
          stat.mtime
          |> NaiveDateTime.from_erl!()
          |> DateTime.from_naive!("Etc/UTC")
          |> DateTime.to_unix(),
        name: Path.basename(path),
        content: File.read!(path),
        size: stat.size,
        type: "image/jpeg"
      }
    end
  end

  describe "Importing a new record" do
    test "it shows the import modal", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/collection")

      import_dialog =
        index_live
        |> element("a", "Import")
        |> render_click()

      assert import_dialog =~ "Search for a record on MusicBrainz"
      assert import_dialog =~ "No results"

      assert_patch(index_live, ~p"/collection/import")
    end

    test "it imports a record when selected", %{conn: conn} do
      {:ok, import_live, _html} = live(conn, ~p"/collection/import")

      mock_results = release_group_search_results()

      expect(APIBehaviourMock, :search_release_group, fn "Marillion Marbles",
                                                         limit: 10,
                                                         offset: 0 ->
        {:ok, mock_results}
      end)

      assert import_live
             |> element("#import_form")
             |> render_change(%{mb_query: "Marillion Marbles"})

      updated_list = import_live |> render()

      for result <- mock_results do
        assert updated_list =~ result.title
        assert updated_list =~ Record.format_release(result.release)
        assert updated_list =~ result.artists
      end

      first_result = hd(mock_results)
      first_result_id = first_result.id

      release_group = release_group()

      expect(APIBehaviourMock, :get_release_group, fn ^first_result_id ->
        {:ok, release_group}
      end)

      cover_data = File.read!(marbles_cover_fixture())

      expect(APIBehaviourMock, :get_cover_art, fn {:musicbrainz_id, ^first_result_id} ->
        {:ok, cover_data}
      end)

      import_live
      |> element("#musicbrainz_#{first_result_id} a", "CD")
      |> render_click()

      [record] = MusicLibrary.Repo.all(MusicLibrary.Records.Record)

      assert record.musicbrainz_id == first_result_id
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

      assert %MusicLibrary.Records.Record.Artist{
               name: "Marillion",
               sort_name: "Marillion",
               disambiguation: "British progressive rock band",
               musicbrainz_id: "1932f5b6-0b7b-4050-b1df-833ca89e5f44"
             } = marillion

      assert_redirect(import_live, ~p"/collection/#{record.id}")
    end
  end
end
