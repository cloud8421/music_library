defmodule MusicLibraryWeb.RecordSetLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.RecordSets
  import Phoenix.LiveViewTest

  alias MusicLibrary.RecordSets

  describe "Index" do
    test "lists record sets with names and record counts", %{conn: conn} do
      {_set, _records} = record_set_with_records(2, %{name: "My Favorites"})

      conn
      |> visit(~p"/record-sets")
      |> assert_has("h1", text: "Record Sets")
      |> assert_has("h2", text: "My Favorites")
    end

    test "shows empty state when no sets exist", %{conn: conn} do
      conn
      |> visit(~p"/record-sets")
      |> assert_has("p", text: "No record sets yet")
    end
  end

  describe "Search" do
    test "filters sets by query", %{conn: conn} do
      record_set(%{name: "Road Trip"})
      record_set(%{name: "Unrelated Set"})

      conn
      |> visit(~p"/record-sets?query=Road")
      |> assert_has("h2", text: "Road Trip")
      |> refute_has("h2", text: "Unrelated Set")
    end
  end

  describe "Ordering" do
    test "switches to alphabetical via URL param", %{conn: conn} do
      record_set(%{name: "Zulu Set"})
      record_set(%{name: "Alpha Set"})

      {:ok, _view, html} = live(conn, ~p"/record-sets?order=alphabetical")

      alpha_pos = :binary.match(html, "Alpha Set")
      zulu_pos = :binary.match(html, "Zulu Set")

      assert alpha_pos < zulu_pos
    end
  end

  describe "Create set" do
    test "creates a set with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/record-sets/new")

      view
      |> form("#record-set-form", record_set: %{name: "Brand New Set"})
      |> render_submit()

      assert [set] = RecordSets.search_record_sets("Brand New Set")
      assert set.name == "Brand New Set"
    end

    test "shows validation errors with invalid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/record-sets/new")

      html =
        view
        |> form("#record-set-form", record_set: %{name: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Edit set" do
    test "updates set with valid data", %{conn: conn} do
      set = record_set(%{name: "Old Name"})

      {:ok, view, _html} = live(conn, ~p"/record-sets/#{set}/edit")

      view
      |> form("#record-set-form", record_set: %{name: "Updated Name"})
      |> render_submit()

      updated = RecordSets.get_record_set!(set.id)
      assert updated.name == "Updated Name"
    end
  end

  describe "Delete set" do
    test "deletes a set from the listing", %{conn: conn} do
      set = record_set(%{name: "To Delete"})

      {:ok, view, _html} = live(conn, ~p"/record-sets")

      view
      |> element("button[phx-click='delete_set'][phx-value-id='#{set.id}']")
      |> render_click()

      refute has_element?(view, "h2", "To Delete")
      assert_raise Ecto.NoResultsError, fn -> RecordSets.get_record_set!(set.id) end
    end
  end

  describe "Remove record from set" do
    test "removes a record from the set", %{conn: conn} do
      {set, [r1 | _]} = record_set_with_records(2)

      {:ok, view, _html} = live(conn, ~p"/record-sets")

      view
      |> element(
        "button[phx-click='remove_record'][phx-value-set-id='#{set.id}'][phx-value-record-id='#{r1.id}']"
      )
      |> render_click()

      updated = RecordSets.get_record_set!(set.id)
      refute Enum.any?(updated.items, &(&1.record.id == r1.id))
    end
  end

  describe "Reorder records" do
    test "moves a record left (up)", %{conn: conn} do
      {set, [r1, r2 | _]} = record_set_with_records(3)

      {:ok, view, _html} = live(conn, ~p"/record-sets")

      view
      |> element(
        "button[phx-click='move_up'][phx-value-set-id='#{set.id}'][phx-value-record-id='#{r2.id}']"
      )
      |> render_click()

      updated = RecordSets.get_record_set!(set.id)
      ids_in_order = Enum.map(updated.items, & &1.record.id)
      assert Enum.at(ids_in_order, 0) == r2.id
      assert Enum.at(ids_in_order, 1) == r1.id
    end

    test "moves a record right (down)", %{conn: conn} do
      {set, [r1, r2 | _]} = record_set_with_records(3)

      {:ok, view, _html} = live(conn, ~p"/record-sets")

      view
      |> element(
        "button[phx-click='move_down'][phx-value-set-id='#{set.id}'][phx-value-record-id='#{r1.id}']"
      )
      |> render_click()

      updated = RecordSets.get_record_set!(set.id)
      ids_in_order = Enum.map(updated.items, & &1.record.id)
      assert Enum.at(ids_in_order, 0) == r2.id
      assert Enum.at(ids_in_order, 1) == r1.id
    end
  end
end
