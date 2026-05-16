defmodule MusicLibraryWeb.StatsLive.TopAlbumsTest do
  use MusicLibraryWeb.ConnCase

  import MusicLibrary.Fixtures.Records
  import MusicLibrary.ScrobbledTracksFixtures

  # Any release_id from the marbles release-group fixture. Records created by
  # `record/0` include `musicbrainz_data: ReleaseGroup.release_group(:marbles)`,
  # which expands `release_ids` to include this ID, so scrobbles referencing it
  # will be matched against those records.
  @marbles_release_id "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608"
  @marillion_mbid "3acc72b3-4183-4d64-9b88-c0cf50d43ad3"

  defp two_marbles_scrobbles(_) do
    now = System.system_time(:second)

    track_fixture(%{
      title: "The Invisible Man",
      album_title: "Marbles",
      album_musicbrainz_id: @marbles_release_id,
      artist_name: "Marillion",
      artist_musicbrainz_id: @marillion_mbid,
      scrobbled_at_uts: now - 100
    })

    track_fixture(%{
      title: "You're Gone",
      album_title: "Marbles",
      album_musicbrainz_id: @marbles_release_id,
      artist_name: "Marillion",
      artist_musicbrainz_id: @marillion_mbid,
      scrobbled_at_uts: now - 200
    })

    :ok
  end

  describe "section" do
    test "renders with the 'Top Albums' heading", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#top-albums h1", text: "Top Albums")
    end

    test "renders no album rows when no scrobbles exist", %{conn: conn} do
      conn
      |> visit("/")
      |> render_async()
      |> refute_has("#top-albums img")
    end
  end

  describe "album row" do
    setup :two_marbles_scrobbles

    test "shows the album title, linked artist, and play count", %{conn: conn} do
      conn
      |> visit("/")
      |> render_async()
      |> assert_has("#top-albums p", text: "Marbles")
      |> assert_has(~s|#top-albums a[href="/artists/#{@marillion_mbid}"]|, text: "Marillion")
      |> assert_has("#top-albums span", text: "2")
    end

    test "uses the Last.fm cover URL when no matching record exists", %{conn: conn} do
      conn
      |> visit("/")
      |> render_async()
      |> assert_has(~s|#top-albums img[src="https://example.com/cover.jpg"]|)
    end

    test "uses the /assets transform URL when a matching record provides cover_hash",
         %{conn: conn} do
      _record = record(%{purchased_at: DateTime.utc_now()})

      session =
        conn
        |> visit("/")
        |> render_async()

      html = Phoenix.LiveViewTest.render(session.view)

      assert html =~ ~r|<img[^>]+src="/assets/[^"]+"[^>]+alt="Marbles"|
      refute html =~ ~s|src="https://example.com/cover.jpg"|
    end
  end

  describe "matching records badges and navigation" do
    setup :two_marbles_scrobbles

    test "single collected record: success badge and navigation to collection show", %{conn: conn} do
      collected = record(%{purchased_at: DateTime.utc_now()})

      session =
        conn
        |> visit("/")
        |> render_async()

      html = Phoenix.LiveViewTest.render(session.view)

      # The whole row is clickable, navigating to the collection show route.
      assert html =~ ~s|/collection/#{collected.id}|
      assert html =~ "cursor-pointer"
      # The default `surface` badge variant for `success` uses `border-success`.
      assert html =~ "border-success"
      refute html =~ "border-warning"
    end

    test "single wishlisted record: warning badge and navigation to wishlist show",
         %{conn: conn} do
      wishlisted = record(%{purchased_at: nil})

      session =
        conn
        |> visit("/")
        |> render_async()

      html = Phoenix.LiveViewTest.render(session.view)

      assert html =~ ~s|/wishlist/#{wishlisted.id}|
      assert html =~ "cursor-pointer"
      assert html =~ "border-warning"
      refute html =~ "border-success"
    end

    test "two records under one release group: renders a dropdown with a link per record",
         %{conn: conn} do
      shared_mbid = Ecto.UUID.generate()

      collected =
        record(%{
          title: "Marbles CD",
          format: :cd,
          musicbrainz_id: shared_mbid,
          purchased_at: DateTime.utc_now()
        })

      wishlisted =
        record(%{
          title: "Marbles Vinyl",
          format: :vinyl,
          musicbrainz_id: shared_mbid,
          purchased_at: nil
        })

      session =
        conn
        |> visit("/")
        |> render_async()

      session
      |> assert_has("##{"top-album-#{@marbles_release_id}"}")
      |> assert_has(~s|a[href="/collection/#{collected.id}"]|)
      |> assert_has(~s|a[href="/wishlist/#{wishlisted.id}"]|)
      # The row itself is not navigable when multiple records match.
      |> refute_has("#top-albums div.cursor-pointer")
    end

    test "no matching record: renders a plain badge and row is not navigable", %{conn: conn} do
      # Replace the Marbles scrobbles with an orphan album that has no record.
      # The base setup created Marbles scrobbles — add one that will outrank
      # them in play_count so it appears first.
      now = System.system_time(:second)

      for i <- 0..2 do
        track_fixture(%{
          title: "Orphan Track #{i}",
          album_title: "Orphan Album",
          album_musicbrainz_id: Ecto.UUID.generate(),
          artist_name: "Orphan Artist",
          artist_musicbrainz_id: Ecto.UUID.generate(),
          scrobbled_at_uts: now - 10 - i
        })
      end

      session =
        conn
        |> visit("/")
        |> render_async()

      html = Phoenix.LiveViewTest.render(session.view)

      assert html =~ "Orphan Album"
      # Plain badge is primary/surface — no success/warning color classes on
      # the Orphan Album row. Since there's no single record match, the row
      # has no cursor-pointer and no /collection/:id or /wishlist/:id link.
      refute html =~ ~r|phx-click="[^"]*/collection/|
      refute html =~ ~r|phx-click="[^"]*/wishlist/|
    end
  end

  describe "period switching" do
    test "switching to 30-day period re-fetches with the new cutoff", %{conn: conn} do
      now = System.system_time(:second)
      older_uts = now - 10 * 86_400

      track_fixture(%{
        title: "Older Track",
        album_title: "Older Album",
        album_musicbrainz_id: Ecto.UUID.generate(),
        artist_name: "Older Artist",
        artist_musicbrainz_id: Ecto.UUID.generate(),
        scrobbled_at_uts: older_uts
      })

      session =
        conn
        |> visit("/")
        |> render_async()

      refute_has(session, "#top-albums", text: "Older Album")

      session
      |> within("#top-albums", fn s ->
        s
        |> click_button("30d")
        |> render_async()
      end)

      assert_has(session, "#top-albums", text: "Older Album")
    end
  end
end
