defmodule MusicLibraryWeb.MaintenanceLive.IndexTest do
  use MusicLibraryWeb.ConnCase
  use Oban.Testing, repo: MusicLibrary.BackgroundRepo

  import MusicLibrary.ArtistInfoFixtures
  import MusicLibrary.Fixtures.Records
  import Phoenix.LiveViewTest

  alias MusicLibrary.Secrets

  describe "Maintenance page" do
    test "renders all sections and Last.fm status", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/maintenance")

      assert html =~ "Records"
      assert html =~ "Artists"
      assert html =~ "Database"
      assert html =~ "Assets"
      assert html =~ "Emails"
      assert html =~ "Last.fm"
    end

    test "async status resolves to :not_connected when no session key is stored", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/maintenance")

      assert render_async(view) =~ "Not connected"
    end

    test "async status resolves to connected when session key is valid", %{conn: conn} do
      {:ok, _} = Secrets.store("last_fm_session_key", "sk-xyz")

      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, %{"user" => %{"name" => "alice"}})
      end)

      {:ok, view, _html} = live(conn, ~p"/maintenance")

      assert render_async(view) =~ "Connected as alice"
    end
  end

  describe "records section" do
    test "'Refresh MusicBrainz data' enqueues a RecordRefreshMusicBrainzData job per record",
         %{conn: conn} do
      r1 = record()
      r2 = record()

      {:ok, view, _html} = live(conn, ~p"/maintenance")

      render_click(view, "refresh_records_musicbrainz_data")

      assert_enqueued(
        worker: MusicLibrary.Worker.RecordRefreshMusicBrainzData,
        args: %{"id" => r1.id}
      )

      assert_enqueued(
        worker: MusicLibrary.Worker.RecordRefreshMusicBrainzData,
        args: %{"id" => r2.id}
      )

      assert render(view) =~ "Operation started in the background."
    end

    test "'Regenerate record embeddings' enqueues a GenerateRecordEmbedding job per record",
         %{conn: conn} do
      r1 = record()

      {:ok, view, _html} = live(conn, ~p"/maintenance")

      render_click(view, "generate_record_embeddings")

      assert_enqueued(
        worker: MusicLibrary.Worker.GenerateRecordEmbedding,
        args: %{"record_id" => r1.id}
      )

      assert render(view) =~ "Operation started in the background."
    end
  end

  describe "artists section" do
    setup do
      artist_info = artist_info_fixture()
      %{artist_info: artist_info}
    end

    for {event, worker} <- [
          {"refresh_artists_musicbrainz_data", MusicLibrary.Worker.ArtistRefreshMusicBrainzData},
          {"refresh_artists_discogs_data", MusicLibrary.Worker.ArtistRefreshDiscogsData},
          {"refresh_artists_wikipedia_data", MusicLibrary.Worker.ArtistRefreshWikipediaData},
          {"refresh_artists_lastfm_data", MusicLibrary.Worker.FetchArtistLastFmData}
        ] do
      test "'#{event}' enqueues a #{inspect(worker)} job per artist", %{
        conn: conn,
        artist_info: artist_info
      } do
        {:ok, view, _html} = live(conn, ~p"/maintenance")

        render_click(view, unquote(event))

        assert_enqueued(worker: unquote(worker), args: %{"id" => artist_info.id})

        assert render(view) =~ "Operation started in the background."
      end
    end
  end

  describe "database section" do
    test "'Optimize' runs PRAGMA optimize and toasts success", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/maintenance")

      render_click(view, "db_optimize")

      assert render(view) =~ "Database optimized successfully."
    end
  end

  describe "assets section" do
    test "'Prune asset cache' runs synchronously and reports the pruned count", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/maintenance")

      render_click(view, "prune_asset_cache")

      assert render(view) =~ "Pruned 0 cached assets."
    end

    test "'Prune unreferenced assets' enqueues a PruneAssets job", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/maintenance")

      render_click(view, "prune_assets")

      assert_enqueued(worker: MusicLibrary.Worker.PruneAssets)
      assert render(view) =~ "Asset pruning started in the background."
    end
  end

  describe "emails section" do
    test "'Send records on this day' shows the :no_records toast when the collection is empty",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/maintenance")

      render_click(view, "send_records_on_this_day_email")

      assert render(view) =~ "No records on this day."
    end
  end

  describe "Last.fm section" do
    @tag :capture_log
    test "'Re-connect to Last.fm' deletes the stored session key and redirects externally",
         %{conn: conn} do
      {:ok, _} = Secrets.store("last_fm_session_key", "sk-xyz")
      {:ok, view, _html} = live(conn, ~p"/maintenance")

      assert {:error, {:redirect, %{to: url}}} = render_click(view, "reconnect_lastfm")

      assert url == LastFm.auth_url()
      assert Secrets.get("last_fm_session_key") == nil
    end
  end
end
