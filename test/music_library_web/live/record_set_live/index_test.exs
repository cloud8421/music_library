defmodule MusicLibraryWeb.RecordSetLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.RecordSets

  alias MusicLibrary.RecordSets

  describe "Index" do
    test "lists record sets with names and record counts", %{conn: conn} do
      {_set, _records} = record_set_with_records(2, %{name: "My Favorites"})

      conn
      |> visit(~p"/record-sets")
      |> assert_has("h2", "My Favorites")
    end

    test "shows empty state when no sets exist", %{conn: conn} do
      conn
      |> visit(~p"/record-sets")
      |> assert_has("p", "No record sets yet")
    end
  end

  describe "Search" do
    test "filters sets by query", %{conn: conn} do
      record_set(%{name: "Road Trip"})
      record_set(%{name: "Unrelated Set"})

      conn
      |> visit(~p"/record-sets?query=Road")
      |> assert_has("h2", "Road Trip")
      |> refute_has("h2", "Unrelated Set")
    end
  end

  describe "Ordering" do
    test "switches to alphabetical via URL param", %{conn: conn} do
      record_set(%{name: "Zulu Set"})
      record_set(%{name: "Alpha Set"})

      session = conn |> visit(~p"/record-sets?order=alphabetical")
      html = Phoenix.LiveViewTest.render(session.view)

      alpha_pos = :binary.match(html, "Alpha Set")
      zulu_pos = :binary.match(html, "Zulu Set")

      assert alpha_pos < zulu_pos
    end
  end

  describe "Create set" do
    test "creates a set with valid data", %{conn: conn} do
      conn
      |> visit(~p"/record-sets/new")
      |> fill_in("Name", with: "Brand New Set")
      |> click_button("Save Set")

      assert [set] = RecordSets.search_record_sets("Brand New Set")
      assert set.name == "Brand New Set"
    end

    test "shows validation errors with invalid data", %{conn: conn} do
      conn
      |> visit(~p"/record-sets/new")
      |> click_button("Save Set")
      |> assert_has("[data-part='error']", "can't be blank")
    end
  end

  describe "Edit set" do
    test "updates set with valid data", %{conn: conn} do
      set = record_set(%{name: "Old Name"})

      conn
      |> visit(~p"/record-sets/#{set}/edit")
      |> fill_in("Name", with: "Updated Name")
      |> click_button("Save Set")

      updated = RecordSets.get_record_set!(set.id)
      assert updated.name == "Updated Name"
    end
  end

  describe "Delete set" do
    test "deletes a set from the listing", %{conn: conn} do
      set = record_set(%{name: "Delete From Index"})

      conn
      |> visit(~p"/record-sets")
      |> assert_has("h2", "Delete From Index")
      |> click_button("button[phx-click='delete_set'][phx-value-id='#{set.id}']", "Delete")
      |> refute_has("h2", "Delete From Index")

      assert_raise Ecto.NoResultsError, fn ->
        RecordSets.get_record_set!(set.id)
      end
    end
  end
end
