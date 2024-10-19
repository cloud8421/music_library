defmodule MusicLibraryWeb.RecordIndexTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest
  import MusicLibrary.RecordsFixtures
  import Mox
  alias MusicLibrary.Records.Record

  setup :verify_on_exit!

  @default_records_page_size 100
  @total_records @default_records_page_size + 10

  defp create_records(_) do
    records = Enum.map(1..@total_records, fn _ -> record_fixture() end)
    %{records: records}
  end

  defp escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  describe "Paginated list of records" do
    setup [:create_records]

    test "uses default params", %{conn: conn, records: records} do
      {:ok, index_live, html} = live(conn, ~p"/records")

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

    test "uses query string params", %{conn: conn, records: records} do
      {:ok, page_2_live, page_2_html} = live(conn, ~p"/records?page=2&page_size=25")

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

      {:ok, page_3_live, page_3_html} = live(conn, ~p"/records?page=3&page_size=25")

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
    setup [:create_records]

    test "supports raw queries", %{conn: conn, records: records} do
      [record | _rest] = records
      qs = [query: record.title]
      {:ok, index_live, _html} = live(conn, ~p"/records?#{qs}")

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

    test "supports filters", %{conn: conn, records: records} do
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

      qs = [query: ~s(artist:"#{artist_with_most_records}"), page_size: 30]
      {:ok, index_live, _html} = live(conn, ~p"/records?#{qs}")

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

      {:ok, index_live, _html} = live(conn, ~p"/records")

      assert index_live
             |> element("#records-#{record.id} a", "Edit")
             |> render_click() =~ "Edit"

      assert_patch(index_live, ~p"/records/#{record}/edit")

      assert index_live |> render() =~ "Edit"
    end

    test "can change the record cover", %{conn: conn} do
      record = record_fixture(cover_data: File.read!(marbles_cover_fixture()))
      {:ok, form_live, html} = live(conn, ~p"/records/#{record.id}/edit")

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
      {:ok, index_live, _html} = live(conn, ~p"/records")

      import_dialog =
        index_live
        |> element("a", "Import")
        |> render_click()

      assert import_dialog =~ "Search for a record on MusicBrainz"
      assert import_dialog =~ "No results"

      assert_patch(index_live, ~p"/records/import")
    end

    test "it imports a record when selected", %{conn: conn} do
      {:ok, import_live, _html} = live(conn, ~p"/records/import")

      mock_results =
        [
          %{
            id: "20790e26-98e4-3ad3-a67f-b674758b942d",
            type: :album,
            title: "Marbles",
            artists: "Marillion",
            release: "2004-05-03"
          },
          %{
            id: "bf20ac32-a793-3bb4-beff-f7b9bffaca38",
            type: :album,
            title: "Marbles Live",
            artists: "Marillion",
            release: "2005-10-24"
          }
        ]

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
        assert updated_list =~ result.release
        assert updated_list =~ result.artists
      end

      first_result = hd(mock_results)
      first_result_id = first_result.id

      release_group = %{
        "artist-credit" => [
          %{
            "artist" => %{
              "disambiguation" => "British progressive rock band",
              "genres" => [
                %{
                  "count" => 10,
                  "disambiguation" => "",
                  "id" => "ae9b8279-3959-48d8-8a88-741a7f6d4a48",
                  "name" => "progressive rock"
                }
              ],
              "id" => "1932f5b6-0b7b-4050-b1df-833ca89e5f44",
              "name" => "Marillion",
              "sort-name" => "Marillion",
              "type" => "Group",
              "type-id" => "e431f5f6-b5d2-343d-8b36-72607fffb74b"
            },
            "joinphrase" => "",
            "name" => "Marillion"
          }
        ],
        "disambiguation" => "",
        "first-release-date" => "2004-05-03",
        "genres" => [
          %{
            "count" => 1,
            "disambiguation" => "",
            "id" => "ceeaa283-5d7b-4202-8d1d-e25d116b2a18",
            "name" => "alternative rock"
          },
          %{
            "count" => 1,
            "disambiguation" => "",
            "id" => "b7ef058e-6d83-4ca4-8123-9724bff4648b",
            "name" => "art rock"
          },
          %{
            "count" => 1,
            "disambiguation" => "",
            "id" => "150eb95a-7739-4fde-a5fe-b62ca576a928",
            "name" => "baroque pop"
          },
          %{
            "count" => 1,
            "disambiguation" => "",
            "id" => "797e2e85-5ffd-495c-a757-8b4079052f0e",
            "name" => "pop rock"
          },
          %{
            "count" => 2,
            "disambiguation" => "",
            "id" => "ae9b8279-3959-48d8-8a88-741a7f6d4a48",
            "name" => "progressive rock"
          },
          %{
            "count" => 1,
            "disambiguation" => "",
            "id" => "2aeb5340-c474-4677-b9a6-35ddac9b6a58",
            "name" => "psychedelic pop"
          },
          %{
            "count" => 2,
            "disambiguation" => "",
            "id" => "0e3fc579-2d24-4f20-9dae-736e1ec78798",
            "name" => "rock"
          }
        ],
        "id" => "20790e26-98e4-3ad3-a67f-b674758b942d",
        "primary-type" => "Album",
        "primary-type-id" => "f529b476-6e62-324f-b0aa-1f3e33d313fc",
        "secondary-type-ids" => [],
        "secondary-types" => [],
        "title" => "Marbles"
      }

      expect(APIBehaviourMock, :get_release_group, fn ^first_result_id ->
        {:ok, release_group}
      end)

      cover_data = File.read!(marbles_cover_fixture())

      expect(APIBehaviourMock, :get_cover_art, fn ^first_result_id ->
        {:ok, cover_data}
      end)

      import_live
      |> element("#musicbrainz_#{first_result_id} button", "CD")
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
               "599407DDF69907D4A60FE13CCAA824D25CF08DC124FD6AA3E8E7ECD98C885FFE"

      assert record.cover_data == cover_data

      assert record.inserted_at !== nil
      assert record.updated_at !== nil
      assert record.purchased_at !== nil

      [marillion] = record.artists

      assert %MusicLibrary.Records.Record.Artist{
               id: _,
               name: "Marillion",
               sort_name: "Marillion",
               disambiguation: "British progressive rock band",
               musicbrainz_id: "1932f5b6-0b7b-4050-b1df-833ca89e5f44"
             } = marillion

      assert_redirect(import_live, ~p"/records/#{record.id}")
    end
  end
end
