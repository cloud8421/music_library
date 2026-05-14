defmodule MusicLibraryWeb.MaintenanceLive.IndexTest do
  use MusicLibraryWeb.ConnCase
  use Oban.Testing, repo: MusicLibrary.BackgroundRepo

  import MusicLibrary.ArtistInfoFixtures
  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Secrets

  describe "Maintenance page" do
    test "renders all sections and Last.fm status", %{conn: conn} do
      conn
      |> visit(~p"/maintenance")
      |> assert_has("h3", "Records")
      |> assert_has("h3", "Artists")
      |> assert_has("h3", "Database")
      |> assert_has("h3", "Assets")
      |> assert_has("h3", "Emails")
      |> assert_has("h3", "Last.fm")
    end

    test "async status resolves to :not_connected when no session key is stored", %{conn: conn} do
      conn
      |> visit(~p"/maintenance")
      |> unwrap(&render_async/1)
      |> assert_has("span", "Not connected")
    end

    test "async status resolves to connected when session key is valid", %{conn: conn} do
      {:ok, _} = Secrets.store("last_fm_session_key", "sk-xyz")

      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, %{"user" => %{"name" => "alice"}})
      end)

      conn
      |> visit(~p"/maintenance")
      |> unwrap(&render_async/1)
      |> assert_has("span", "Connected as alice")
    end
  end

  describe "records section" do
    test "'Refresh MusicBrainz data' enqueues a RecordRefreshMusicBrainzData job per record",
         %{conn: conn} do
      r1 = record()
      r2 = record()

      session =
        conn
        |> visit(~p"/maintenance")
        |> click_button(
          "button[phx-click='refresh_records_musicbrainz_data']",
          "Refresh MusicBrainz data"
        )

      assert_enqueued(
        worker: MusicLibrary.Worker.RecordRefreshMusicBrainzData,
        args: %{"id" => r1.id}
      )

      assert_enqueued(
        worker: MusicLibrary.Worker.RecordRefreshMusicBrainzData,
        args: %{"id" => r2.id}
      )

      assert_has(session, "p", "Operation started in the background.")
    end

    test "'Regenerate record embeddings' enqueues a GenerateRecordEmbedding job per record",
         %{conn: conn} do
      r1 = record()

      session =
        conn
        |> visit(~p"/maintenance")
        |> click_button("Regenerate record embeddings")

      assert_enqueued(
        worker: MusicLibrary.Worker.GenerateRecordEmbedding,
        args: %{"record_id" => r1.id}
      )

      assert_has(session, "p", "Operation started in the background.")
    end
  end

  describe "artists section" do
    setup do
      artist_info = artist_info_fixture()
      %{artist_info: artist_info}
    end

    for {event, button_text, worker} <- [
          {"refresh_artists_musicbrainz_data", "Refresh MusicBrainz data",
           MusicLibrary.Worker.ArtistRefreshMusicBrainzData},
          {"refresh_artists_discogs_data", "Refresh Discogs data",
           MusicLibrary.Worker.ArtistRefreshDiscogsData},
          {"refresh_artists_wikipedia_data", "Refresh Wikipedia data",
           MusicLibrary.Worker.ArtistRefreshWikipediaData},
          {"refresh_artists_lastfm_data", "Refresh Last.fm data",
           MusicLibrary.Worker.FetchArtistLastFmData}
        ] do
      test "'#{event}' enqueues a #{inspect(worker)} job per artist", %{
        conn: conn,
        artist_info: artist_info
      } do
        session =
          conn
          |> visit(~p"/maintenance")
          |> click_button(
            "button[phx-click='#{unquote(event)}']",
            unquote(button_text)
          )

        assert_enqueued(worker: unquote(worker), args: %{"id" => artist_info.id})
        assert_has(session, "p", "Operation started in the background.")
      end
    end
  end

  describe "database section" do
    test "'Optimize' runs PRAGMA optimize and toasts success", %{conn: conn} do
      session =
        conn
        |> visit(~p"/maintenance")
        |> click_button("Optimize")

      assert_has(session, "p", "Database optimized successfully.")
    end
  end

  describe "assets section" do
    test "'Prune asset cache' runs synchronously and reports the pruned count", %{conn: conn} do
      session =
        conn
        |> visit(~p"/maintenance")
        |> click_button("Prune asset cache")

      assert_has(session, "p", "Pruned 0 cached assets.")
    end

    test "'Prune unreferenced assets' enqueues a PruneAssets job", %{conn: conn} do
      session =
        conn
        |> visit(~p"/maintenance")
        |> click_button("Prune unreferenced assets")

      assert_enqueued(worker: MusicLibrary.Worker.PruneAssets)
      assert_has(session, "p", "Asset pruning started in the background.")
    end
  end

  describe "emails section" do
    test "'Send records on this day' shows the :no_records toast when the collection is empty",
         %{conn: conn} do
      session =
        conn
        |> visit(~p"/maintenance")
        |> click_button("Send records on this day")

      assert_has(session, "p", "No records on this day.")
    end
  end

  describe "Last.fm section" do
    @tag :capture_log
    test "'Re-connect to Last.fm' deletes the stored session key and redirects externally",
         %{conn: conn} do
      {:ok, _} = Secrets.store("last_fm_session_key", "sk-xyz")

      conn
      |> visit(~p"/maintenance")
      |> click_button("Re-connect to Last.fm")

      assert Secrets.get("last_fm_session_key") == nil
    end
  end
end
