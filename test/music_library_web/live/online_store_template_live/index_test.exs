defmodule MusicLibraryWeb.OnlineStoreTemplateLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.OnlineStoreTemplates
  import Phoenix.LiveViewTest

  describe "Index" do
    test "lists all templates", %{conn: conn} do
      online_store_template(%{name: "Amazon UK"})
      online_store_template(%{name: "Bandcamp"})

      conn
      |> visit(~p"/online-store-templates")
      |> assert_has("h1", "Online Store Templates")
      |> assert_has("p", "Amazon UK")
      |> assert_has("p", "Bandcamp")
    end
  end

  describe "Create template" do
    test "creates with valid data", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/online-store-templates/new")

      view
      |> form("#online_store_template-form",
        online_store_template: %{
          name: "New Store",
          url_template: "https://store.example.com/search?q={artist}+{title}"
        }
      )
      |> render_submit()

      assert has_element?(view, "p", "New Store")
    end

    test "shows validation errors", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/online-store-templates/new")

      html =
        view
        |> form("#online_store_template-form",
          online_store_template: %{name: "", url_template: ""}
        )
        |> render_change()

      assert html =~ "can&#39;t be blank"
    end
  end

  describe "Edit template" do
    test "updates with valid data", %{conn: conn} do
      template = online_store_template(%{name: "Old Name"})

      {:ok, view, _html} = live(conn, ~p"/online-store-templates/#{template}/edit")

      view
      |> form("#online_store_template-form",
        online_store_template: %{name: "Updated Name"}
      )
      |> render_submit()

      assert has_element?(view, "p", "Updated Name")
    end
  end

  describe "Delete template" do
    test "deletes from listing", %{conn: conn} do
      template = online_store_template(%{name: "To Delete"})

      {:ok, view, _html} = live(conn, ~p"/online-store-templates")

      view
      |> element("button[phx-click='delete'][phx-value-id='#{template.id}']")
      |> render_click()

      refute has_element?(view, "p", "To Delete")
    end
  end

  describe "Toggle enabled" do
    test "toggles template enabled status", %{conn: conn} do
      template = online_store_template(%{name: "Toggle Me", enabled: true})

      {:ok, view, _html} = live(conn, ~p"/online-store-templates")

      # Toggle to disabled
      html =
        view
        |> element("button[phx-click='toggle-enabled'][phx-value-id='#{template.id}']")
        |> render_click()

      assert html =~ "Enable template"

      # Toggle back to enabled
      html =
        view
        |> element("button[phx-click='toggle-enabled'][phx-value-id='#{template.id}']")
        |> render_click()

      assert html =~ "Disable template"
    end
  end
end
