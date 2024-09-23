defmodule MusicLibraryWeb.RecordLiveTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest
  import MusicLibrary.RecordsFixtures

  defp create_records(_) do
    records = Enum.map(1..30, fn _ -> record_fixture() end)
    %{records: records}
  end

  defp escape(string) do
    string
    |> Phoenix.HTML.html_escape()
    |> Phoenix.HTML.safe_to_string()
  end

  describe "Paginated list of records" do
    setup [:create_records]

    test "lists all records within default pagination params", %{conn: conn, records: records} do
      {:ok, _index_live, html} = live(conn, ~p"/records")

      assert html =~ "Listing Records"

      {present, absent} =
        Enum.split_with(records, fn record ->
          html =~ record.id
        end)

      assert length(present) == 20
      assert length(absent) == 10

      for record <- present do
        assert html =~ escape(record.title)
        assert html =~ to_string(record.year)

        for artist <- record.artists do
          assert html =~ escape(artist["name"])
        end
      end
    end

    test "paginates records", %{conn: conn, records: records} do
      {:ok, page_2_live, page_2_html} = live(conn, ~p"/records?page=2&page_size=5")

      {page_2_present, page_2_absent} =
        Enum.split_with(records, fn record ->
          page_2_html =~ record.id
        end)

      assert length(page_2_present) == 5
      assert length(page_2_absent) == 25

      page_2_pagination = page_2_live |> with_target("#pagination")
      refute has_element?(page_2_pagination, "a", "2")
      assert has_element?(page_2_pagination, "a", "1")
      assert has_element?(page_2_pagination, "a", "3")
      assert has_element?(page_2_pagination, "a", "4")
      assert has_element?(page_2_pagination, "a", "5")

      {:ok, page_3_live, page_3_html} = live(conn, ~p"/records?page=3&page_size=5")

      {page_3_present, page_3_absent} =
        Enum.split_with(records, fn record ->
          page_3_html =~ record.id
        end)

      assert length(page_3_present) == 5
      assert length(page_3_absent) == 25

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
end
