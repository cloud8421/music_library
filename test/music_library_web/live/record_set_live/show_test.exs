defmodule MusicLibraryWeb.RecordSetLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.RecordSets
  import Phoenix.LiveViewTest

  alias MusicLibrary.RecordSets

  describe "Show" do
    test "displays record set name", %{conn: conn} do
      set = record_set(%{name: "My Favorites"})

      conn
      |> visit(~p"/record-sets/#{set}")
      |> assert_has("h1", "My Favorites")
    end

    test "displays collected/total count", %{conn: conn} do
      {set, _records} = record_set_with_records(2)

      conn
      |> visit(~p"/record-sets/#{set}")
      |> assert_has("span", "2/2 records")
    end

    test "displays records in the set", %{conn: conn} do
      {set, [r1, r2]} = record_set_with_records(2)

      conn
      |> visit(~p"/record-sets/#{set}")
      |> assert_has("h2", escape(r1.title))
      |> assert_has("h2", escape(r2.title))
    end

    test "shows add record tile when set has no records", %{conn: conn} do
      set = record_set()

      conn
      |> visit(~p"/record-sets/#{set}")
      |> assert_has("a[href*='add-record']")
    end

    test "renders markdown description as HTML", %{conn: conn} do
      set = record_set(%{description: "This is **bold** text"})

      conn
      |> visit(~p"/record-sets/#{set}")
      |> assert_has("article strong", "bold")
    end
  end

  describe "Remove record" do
    test "removes a record from the set", %{conn: conn} do
      {set, [r1 | _]} = record_set_with_records(2)

      {:ok, view, _html} = live(conn, ~p"/record-sets/#{set}")

      view
      |> element("button[phx-click='remove_record'][phx-value-record-id='#{r1.id}']")
      |> render_click()

      updated = RecordSets.get_record_set!(set.id)
      refute Enum.any?(updated.items, &(&1.record.id == r1.id))
    end
  end

  describe "Drag-and-drop reorder" do
    test "reorders records via reorder event", %{conn: conn} do
      {set, [r1, r2, r3]} = record_set_with_records(3)

      {:ok, view, _html} = live(conn, ~p"/record-sets/#{set}")

      render_hook(view, "reorder", %{"record_ids" => [r3.id, r1.id, r2.id]})

      updated = RecordSets.get_record_set!(set.id)
      ids_in_order = Enum.map(updated.items, & &1.record.id)
      assert ids_in_order == [r3.id, r1.id, r2.id]
    end
  end

  describe "Delete set" do
    test "deletes set and navigates to index", %{conn: conn} do
      set = record_set(%{name: "To Delete"})

      {:ok, view, _html} = live(conn, ~p"/record-sets/#{set}")

      view
      |> element("button[phx-click='delete_set']")
      |> render_click()

      assert_redirect(view, ~p"/record-sets")
      assert_raise Ecto.NoResultsError, fn -> RecordSets.get_record_set!(set.id) end
    end
  end

  describe "Navigation from index" do
    test "index links to show page", %{conn: conn} do
      set = record_set(%{name: "Linked Set"})

      conn
      |> visit(~p"/record-sets")
      |> click_link("Linked Set")
      |> assert_has("h1", "Linked Set")
      |> assert_path(~p"/record-sets/#{set}")
    end
  end
end
