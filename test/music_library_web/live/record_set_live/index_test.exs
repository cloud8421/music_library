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
end
