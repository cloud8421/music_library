defmodule MusicLibraryWeb.ScrobbleRulesLiveTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.ScrobbleRulesFixtures
  import Phoenix.LiveViewTest

  alias MusicLibrary.ScrobbleRules

  # Test data
  @invalid_attrs %{type: "", match_value: "", target_musicbrainz_id: ""}
  @valid_attrs %{
    type: :album,
    match_value: "some match_value",
    target_musicbrainz_id: "12345678-1234-1234-1234-123456789012",
    description: "some description",
    enabled: "true"
  }
  @update_attrs %{
    type: :artist,
    match_value: "some updated match_value",
    target_musicbrainz_id: "87654321-4321-4321-4321-210987654321",
    description: "some updated description"
  }

  defp create_scrobble_rule(_) do
    scrobble_rule = scrobble_rule_fixture()
    %{scrobble_rule: scrobble_rule}
  end

  describe "Index" do
    setup [:create_scrobble_rule]

    test "lists all scrobble_rules", %{conn: conn, scrobble_rule: scrobble_rule} do
      {:ok, _index_live, html} = live(conn, ~p"/scrobble-rules")

      assert html =~ "Scrobble Rules"
      assert html =~ scrobble_rule.match_value
    end

    test "saves new scrobble_rule", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobble-rules")

      assert index_live |> element("a", "Add") |> render_click() =~
               "New Scrobble Rule"

      assert_patch(index_live, ~p"/scrobble-rules/new")

      assert index_live
             |> form("#scrobble_rule-form", scrobble_rule: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      index_live
      |> form("#scrobble_rule-form", scrobble_rule: @valid_attrs)
      |> render_submit()

      # The rule should be created and visible in the list
      html = render(index_live)
      assert html =~ "some match_value"
    end

    test "updates scrobble_rule in listing", %{conn: conn, scrobble_rule: scrobble_rule} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobble-rules")

      assert index_live
             |> element("#scrobble_rules-#{scrobble_rule.id} a[href*='edit']")
             |> render_click() =~
               "Edit Scrobble Rule"

      assert_patch(index_live, ~p"/scrobble-rules/#{scrobble_rule}/edit?page=1&page_size=20")

      assert index_live
             |> form("#scrobble_rule-form", scrobble_rule: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      index_live
      |> form("#scrobble_rule-form", scrobble_rule: @update_attrs)
      |> render_submit()

      html = render(index_live)
      assert html =~ "Scrobble rule updated successfully"
      assert html =~ "some updated match_value"
    end

    test "deletes scrobble_rule in listing", %{conn: conn, scrobble_rule: scrobble_rule} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobble-rules")

      assert index_live
             |> element("#scrobble_rules-#{scrobble_rule.id} button[phx-click='delete']")
             |> render_click()

      refute has_element?(index_live, "#scrobble_rule-#{scrobble_rule.id}")
    end

    test "toggles rule enabled status", %{conn: conn, scrobble_rule: scrobble_rule} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobble-rules")

      # Toggle to disabled
      assert index_live
             |> element("#scrobble_rules-#{scrobble_rule.id} button[phx-click='toggle_enabled']")
             |> render_click()

      # Check that the rule was disabled
      updated_rule = ScrobbleRules.get_scrobble_rule!(scrobble_rule.id)
      refute updated_rule.enabled

      # Toggle back to enabled
      assert index_live
             |> element("#scrobble_rules-#{scrobble_rule.id} button[phx-click='toggle_enabled']")
             |> render_click()

      # Check that the rule was enabled again
      updated_rule = ScrobbleRules.get_scrobble_rule!(scrobble_rule.id)
      assert updated_rule.enabled
    end

    test "applies individual rule", %{conn: conn, scrobble_rule: scrobble_rule} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobble-rules")

      assert index_live
             |> element("#scrobble_rules-#{scrobble_rule.id} button[phx-click='apply_rule']")
             |> render_click()

      # Should show success message (even if no tracks were updated)
      assert render(index_live) =~ "Rule applied successfully"
    end

    test "applies all rules", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobble-rules")

      assert index_live
             |> element("button[phx-click='apply_all_rules']")
             |> render_click()

      # Should show success message
      assert render(index_live) =~ "All rules applied successfully"
    end
  end

  describe "Form validation" do
    test "shows validation errors for missing required fields", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobble-rules")

      assert index_live |> element("a", "Add") |> render_click()

      assert index_live
             |> form("#scrobble_rule-form",
               scrobble_rule: %{type: "", match_value: "", target_musicbrainz_id: ""}
             )
             |> render_change() =~ "can&#39;t be blank"
    end

    test "shows validation errors for invalid MusicBrainz ID", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobble-rules")

      assert index_live |> element("a", "Add") |> render_click()

      assert index_live
             |> form("#scrobble_rule-form",
               scrobble_rule: %{
                 type: :album,
                 match_value: "Test Album",
                 target_musicbrainz_id: "invalid-uuid"
               }
             )
             |> render_change() =~ "is invalid"
    end

    test "updates form labels based on rule type", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/scrobble-rules")

      assert index_live |> element("a", "Add") |> render_click()

      # Select album type
      html =
        index_live
        |> form("#scrobble_rule-form", scrobble_rule: %{type: :album})
        |> render_change()

      assert html =~ "Album Title"

      # Select artist type
      html =
        index_live
        |> form("#scrobble_rule-form", scrobble_rule: %{type: :artist})
        |> render_change()

      assert html =~ "Artist Name"
    end
  end
end
