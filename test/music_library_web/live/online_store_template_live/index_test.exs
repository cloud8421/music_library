defmodule MusicLibraryWeb.OnlineStoreTemplateLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.OnlineStoreTemplates

  alias MusicLibrary.OnlineStoreTemplates

  describe "Index" do
    test "lists all templates", %{conn: conn} do
      online_store_template(%{name: "Amazon UK"})
      online_store_template(%{name: "Bandcamp"})

      conn
      |> visit(~p"/online-store-templates")
      |> assert_has("p", "Amazon UK")
      |> assert_has("p", "Bandcamp")
    end

    test "search filters templates", %{conn: conn} do
      online_store_template(%{name: "Amazon UK"})
      online_store_template(%{name: "Bandcamp"})

      conn
      |> visit(~p"/online-store-templates?#{[query: "Amazon"]}")
      |> assert_has("p", "Amazon UK")
      |> refute_has("p", "Bandcamp")
    end
  end

  describe "Create template" do
    test "creates with valid data", %{conn: conn} do
      conn
      |> visit(~p"/online-store-templates/new")
      |> fill_in("Template Name", with: "New Store")
      |> fill_in("URL Template", with: "https://store.example.com/search?q={artist}+{title}")
      |> click_button("Save Template")
      |> assert_has("p", "New Store")
    end

    test "shows validation errors", %{conn: conn} do
      conn
      |> visit(~p"/online-store-templates/new")
      |> click_button("Save Template")
      |> assert_has("[data-part='error']", "can't be blank")
    end
  end

  describe "Edit template" do
    test "updates with valid data", %{conn: conn} do
      template = online_store_template(%{name: "Old Name"})

      conn
      |> visit(~p"/online-store-templates/#{template}/edit")
      |> fill_in("Template Name", with: "Updated Name")
      |> click_button("Save Template")
      |> assert_has("p", "Updated Name")
    end
  end

  describe "Delete template" do
    test "deletes from listing", %{conn: conn} do
      template = online_store_template(%{name: "To Delete"})

      conn
      |> visit(~p"/online-store-templates")
      |> click_button("button[phx-click='delete'][phx-value-id='#{template.id}']", "Delete")
      |> refute_has("p", "To Delete")

      assert_raise Ecto.NoResultsError, fn ->
        OnlineStoreTemplates.get_template!(template.id)
      end
    end
  end

  describe "Toggle enabled" do
    test "toggles template enabled status", %{conn: conn} do
      template = online_store_template(%{name: "Toggle Me", enabled: true})

      session =
        conn
        |> visit(~p"/online-store-templates")
        |> click_button(
          "button[phx-click='toggle-enabled'][phx-value-id='#{template.id}']",
          "Disable template"
        )

      assert_has(session, "button", "Enable template")

      session
      |> click_button(
        "button[phx-click='toggle-enabled'][phx-value-id='#{template.id}']",
        "Enable template"
      )
      |> assert_has("button", "Disable template")
    end
  end
end
