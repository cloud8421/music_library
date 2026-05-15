defmodule MusicLibraryWeb.ScrobbleRulesLiveTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.ScrobbleRulesFixtures
  import Phoenix.LiveViewTest, only: [render_change: 1, form: 3]

  defp create_scrobble_rule(_) do
    scrobble_rule = scrobble_rule_fixture()
    %{scrobble_rule: scrobble_rule}
  end

  describe "Index" do
    setup [:create_scrobble_rule]

    test "lists all scrobble_rules", %{conn: conn, scrobble_rule: scrobble_rule} do
      conn
      |> visit(~p"/scrobble-rules")
      |> assert_has("p", scrobble_rule.match_value)
    end

    test "saves new scrobble_rule", %{conn: conn} do
      session =
        conn
        |> visit(~p"/scrobble-rules")
        |> click_link("Add")

      assert_has(session, "h1", "New Scrobble Rule")
      assert_path(session, ~p"/scrobble-rules/new")

      # Validation
      conn
      |> visit(~p"/scrobble-rules/new")
      |> click_button("Save Rule")
      |> assert_has("[data-part='error']", "can't be blank")

      # Successful creation
      conn
      |> visit(~p"/scrobble-rules/new")
      |> set_rule_type(:album)
      |> fill_in("Album Title", with: "some match_value")
      |> fill_in("Target MusicBrainz ID",
        with: "12345678-1234-1234-1234-123456789012"
      )
      |> fill_in("Description (optional)", with: "some description")
      |> check("Enable this rule")
      |> click_button("Save Rule")
      |> assert_has("p", "some match_value")
    end

    test "updates scrobble_rule in listing", %{conn: conn, scrobble_rule: scrobble_rule} do
      session =
        conn
        |> visit(~p"/scrobble-rules")
        |> click_link(
          "#scrobble_rules-#{scrobble_rule.id} a[href*='edit']",
          "Edit"
        )

      assert_has(session, "h1", "Edit Scrobble Rule")
      assert_path(session, ~p"/scrobble-rules/#{scrobble_rule}/edit")

      # Validation with cleared fields
      conn
      |> visit(~p"/scrobble-rules/#{scrobble_rule}/edit")
      |> unwrap(fn view ->
        view
        |> form("#scrobble_rule-form",
          scrobble_rule: %{type: "", match_value: "", target_musicbrainz_id: ""}
        )
        |> render_change()
      end)
      |> assert_has("*", "can't be blank")

      # Successful update (fresh session)
      conn
      |> visit(~p"/scrobble-rules/#{scrobble_rule}/edit")
      |> set_rule_type(:artist)
      |> fill_in("Artist Name", with: "some updated match_value")
      |> fill_in("Target MusicBrainz ID",
        with: "87654321-4321-4321-4321-210987654321"
      )
      |> fill_in("Description (optional)", with: "some updated description")
      |> click_button("Save Rule")
      |> assert_has("p", "some updated match_value")
    end

    test "deletes scrobble_rule in listing", %{conn: conn, scrobble_rule: scrobble_rule} do
      conn
      |> visit(~p"/scrobble-rules")
      |> click_button(
        "#scrobble_rules-#{scrobble_rule.id} button[phx-click='delete']",
        "Delete"
      )
      |> refute_has("#scrobble_rule-#{scrobble_rule.id}")
    end

    test "toggles rule enabled status", %{conn: conn, scrobble_rule: scrobble_rule} do
      session = conn |> visit(~p"/scrobble-rules")

      session
      |> click_button(
        "#scrobble_rules-#{scrobble_rule.id} button[phx-click='toggle_enabled']",
        "Disable rule"
      )
      |> assert_has("button", "Enable rule")
      |> click_button(
        "#scrobble_rules-#{scrobble_rule.id} button[phx-click='toggle_enabled']",
        "Enable rule"
      )
      |> assert_has("button", "Disable rule")
    end

    test "applies individual rule", %{conn: conn, scrobble_rule: scrobble_rule} do
      conn
      |> visit(~p"/scrobble-rules")
      |> click_button(
        "#scrobble_rules-#{scrobble_rule.id} button[phx-click='apply_rule']",
        "Apply rule"
      )
      |> assert_has("p", "Rule applied successfully")
    end

    test "applies all rules", %{conn: conn} do
      conn
      |> visit(~p"/scrobble-rules")
      |> click_button("button[phx-click='apply_all_rules']", "Apply")
      |> assert_has("p", "All rules applied successfully")
    end

    test "searches scrobble rules by match_value", %{conn: conn, scrobble_rule: scrobble_rule} do
      _other_rule =
        MusicLibrary.ScrobbleRulesFixtures.scrobble_rule_fixture(%{
          match_value: "Unrelated Album"
        })

      session =
        conn
        |> visit(~p"/scrobble-rules")
        |> search_rules(scrobble_rule.match_value)

      assert_has(session, "p", scrobble_rule.match_value)
      refute_has(session, "p", "Unrelated Album")
    end

    test "switches sort order", %{conn: conn} do
      conn
      |> visit(~p"/scrobble-rules")
      |> click_link("a[href*='order=alphabetical']", "A->Z")
      |> assert_path(~p"/scrobble-rules", query_params: %{order: "alphabetical"})
      |> click_link("a[href*='order=inserted_at']", "Updated")
      |> assert_path(~p"/scrobble-rules", query_params: %{order: "inserted_at"})
    end
  end

  test "updates form labels based on rule type", %{conn: conn} do
    conn
    |> visit(~p"/scrobble-rules")
    |> click_link("Add")
    |> set_rule_type(:album)
    |> assert_has("label", "Album Title")
    |> set_rule_type(:artist)
    |> assert_has("label", "Artist Name")
  end

  defp search_rules(session, query) do
    unwrap(session, fn view ->
      view
      |> form("form[phx-change='search']:not([phx-target])", %{query: query})
      |> render_change()
    end)
  end

  defp set_rule_type(session, type) do
    unwrap(session, fn view ->
      view
      |> form("#scrobble_rule-form", scrobble_rule: %{type: type})
      |> render_change()
    end)
  end
end
