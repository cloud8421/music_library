defmodule MusicLibraryWeb.ScrobbleLive.ReleaseShowTest do
  @moduledoc """
  Smoke tests for the scrobble release page. Full scrobble behaviour
  (picker, selection bar, handlers) is covered by the Release
  LiveComponent tests in `release_test.exs`.
  """
  use MusicLibraryWeb.ConnCase

  alias MusicBrainz.Fixtures.Release, as: ReleaseFixtures
  alias MusicBrainz.Fixtures.ReleaseGroup
  alias Req.Test

  @rg_id ReleaseGroup.release_group_id(:marbles)
  @release_id ReleaseFixtures.release_id(:marbles)

  defp stub_mb(_) do
    Test.stub(MusicBrainz.API, fn conn ->
      case conn.request_path do
        "/ws/2/release/" <> _id ->
          Test.json(conn, ReleaseFixtures.release_with_media(:marbles))

        _ ->
          Test.json(conn, %{})
      end
    end)

    :ok
  end

  describe "ReleaseShow" do
    setup [:stub_mb]

    test "renders the scrobble UI for the release", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@rg_id}/releases/#{@release_id}")
      |> render_async()
      |> assert_has("h2", text: "Marbles")
    end

    test "back link targets the release-group page", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@rg_id}/releases/#{@release_id}")
      |> assert_has("a[href='/scrobble/#{@rg_id}']", text: "Back to releases")
    end

    test "sets the page title once the release loads", %{conn: conn} do
      conn
      |> visit(~p"/scrobble/#{@rg_id}/releases/#{@release_id}")
      |> render_async()
      |> assert_has("title", text: "Marillion - Marbles")
    end
  end
end
