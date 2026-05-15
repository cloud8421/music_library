defmodule MusicLibraryWeb.RecordSetLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.RecordSets
  import MusicLibrary.Fixtures.Records, only: [record: 1]

  import Phoenix.LiveViewTest,
    only: [
      render_click: 1,
      render_hook: 3,
      render_submit: 1,
      element: 2,
      form: 3
    ]

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
      |> assert_has("h3", escape(r1.title))
      |> assert_has("h3", escape(r2.title))
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

      conn
      |> visit(~p"/record-sets/#{set}")
      |> click_button(
        "button[phx-click='remove_record'][phx-value-record-id='#{r1.id}']",
        "Remove"
      )
      |> refute_has(
        "button[phx-click='remove_record'][phx-value-record-id='#{r1.id}']",
        "Remove"
      )
    end
  end

  describe "Drag-and-drop reorder" do
    test "reorders records via reorder event", %{conn: conn} do
      {set, [r1, r2, r3]} = record_set_with_records(3)

      session = conn |> visit(~p"/record-sets/#{set}")

      unwrap(session, &render_hook(&1, "reorder", %{"record_ids" => [r3.id, r1.id, r2.id]}))

      updated = RecordSets.get_record_set!(set.id)
      ids_in_order = Enum.map(updated.items, & &1.record.id)
      assert ids_in_order == [r3.id, r1.id, r2.id]
    end
  end

  describe "Delete set" do
    test "deletes set and navigates to index", %{conn: conn} do
      set = record_set(%{name: "To Delete"})

      conn
      |> visit(~p"/record-sets/#{set}")
      |> click_button("button[phx-click='delete_set']", "Delete")
      |> assert_path(~p"/record-sets")
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

  describe "Add record" do
    test "opens the picker modal", %{conn: conn} do
      set = record_set()

      conn
      |> visit(~p"/record-sets/#{set}/show/add-record")
      |> assert_has("h1", text: "Add Record")
      |> assert_has("#record-picker-search-input")
    end

    test "shows collected records matching the query", %{conn: conn} do
      set = record_set()
      collected = record(%{title: "Collected Unique Xyzzy", purchased_at: DateTime.utc_now()})

      session =
        conn
        |> visit(~p"/record-sets/#{set}/show/add-record")
        |> search_picker("Xyzzy")

      assert_has(session, "h3", "Collected")
      assert_has(session, "p", collected.title)
    end

    test "shows wishlisted records matching the query", %{conn: conn} do
      set = record_set()
      wishlisted = record(%{title: "Wishlisted Unique Xyzzy", purchased_at: nil})

      session =
        conn
        |> visit(~p"/record-sets/#{set}/show/add-record")
        |> search_picker("Xyzzy")

      assert_has(session, "h3", "Wishlisted")
      assert_has(session, "p", wishlisted.title)
    end

    test "shows 'No records found' for non-matching queries", %{conn: conn} do
      set = record_set()

      session =
        conn
        |> visit(~p"/record-sets/#{set}/show/add-record")
        |> search_picker("NonexistentTitleZzzzzzzz")

      assert_has(session, "p", "No records found")
    end

    test "adds a record to the set", %{conn: conn} do
      set = record_set()
      picked = record(%{title: "Pickable Unique Xyzzy", purchased_at: DateTime.utc_now()})

      session =
        conn
        |> visit(~p"/record-sets/#{set}/show/add-record")
        |> search_picker("Xyzzy")

      unwrap(session, fn view ->
        view
        |> element("li[phx-click='add_record'][phx-value-record-id='#{picked.id}']")
        |> render_click()
      end)

      updated = RecordSets.get_record_set!(set.id)
      assert Enum.any?(updated.items, fn item -> item.record.id == picked.id end)
    end

    test "excludes records already in the set from results", %{conn: conn} do
      set = record_set()
      existing = record(%{title: "Already In Set Xyzzy", purchased_at: DateTime.utc_now()})
      {:ok, _} = RecordSets.add_record_to_set(set, existing.id)

      session =
        conn
        |> visit(~p"/record-sets/#{set}/show/add-record")
        |> search_picker("Xyzzy")

      refute_has(
        session,
        "li[phx-click='add_record'][phx-value-record-id='#{existing.id}']"
      )
    end
  end

  defp search_picker(session, query) do
    unwrap(session, fn view ->
      view
      |> form("#record-picker-navigation form", %{query: query})
      |> render_submit()
    end)
  end
end
