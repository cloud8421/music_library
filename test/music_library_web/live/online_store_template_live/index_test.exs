defmodule MusicLibraryWeb.OnlineStoreTemplateLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.OnlineStoreTemplates
  import Phoenix.LiveViewTest

  alias MusicLibrary.OnlineStoreTemplates

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

      templates = OnlineStoreTemplates.list_templates()
      assert Enum.any?(templates, &(&1.name == "New Store"))
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

      updated = OnlineStoreTemplates.get_template!(template.id)
      assert updated.name == "Updated Name"
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
      assert_raise Ecto.NoResultsError, fn -> OnlineStoreTemplates.get_template!(template.id) end
    end
  end

  describe "Toggle enabled" do
    test "toggles template enabled status", %{conn: conn} do
      template = online_store_template(%{name: "Toggle Me", enabled: true})

      {:ok, view, _html} = live(conn, ~p"/online-store-templates")

      # Toggle to disabled
      view
      |> element("button[phx-click='toggle-enabled'][phx-value-id='#{template.id}']")
      |> render_click()

      updated = OnlineStoreTemplates.get_template!(template.id)
      refute updated.enabled

      # Toggle back to enabled
      view
      |> element("button[phx-click='toggle-enabled'][phx-value-id='#{template.id}']")
      |> render_click()

      updated = OnlineStoreTemplates.get_template!(template.id)
      assert updated.enabled
    end
  end
end
