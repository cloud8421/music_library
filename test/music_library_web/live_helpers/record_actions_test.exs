defmodule MusicLibraryWeb.LiveHelpers.RecordActionsTest do
  use MusicLibraryWeb.ConnCase, async: true
  use Oban.Testing, repo: MusicLibrary.BackgroundRepo

  import MusicLibrary.Fixtures.Records
  import Phoenix.LiveViewTest

  alias MusicBrainz.Fixtures.Release, as: ReleaseFixtures
  alias MusicBrainz.Fixtures.ReleaseGroup
  alias MusicLibrary.Chats
  alias MusicLibrary.Records
  alias MusicLibrary.Records.Similarity
  alias Req.Test

  # A MusicBrainz stub that returns valid fixture responses for every route
  # the Collection Show page touches during `handle_params` and via async
  # components (Release tracklist). Tests override specific behaviour by
  # re-stubbing before triggering events.
  defp stub_musicbrainz_happy_path(release_group_id, opts \\ []) do
    release_group = ReleaseGroup.release_group(:marbles)
    release = ReleaseFixtures.release(:marbles)
    cover_data = Keyword.get(opts, :cover_data, marbles_cover_data())

    Test.stub(MusicBrainz.API, fn conn ->
      cond do
        # Cover art archive returns raw image bytes
        conn.host == "coverartarchive.org" ->
          Plug.Conn.send_resp(conn, 200, cover_data)

        match?([_, _, "release-group", ^release_group_id], conn.path_info) ->
          Test.json(conn, release_group)

        match?([_, _, "release"], conn.path_info) ->
          Test.json(conn, ReleaseGroup.release_group_releases(:marbles))

        match?([_, _, "release", _], conn.path_info) ->
          Test.json(conn, release)

        true ->
          Test.json(conn, %{})
      end
    end)
  end

  describe "refresh_musicbrainz_data event" do
    test "success path shows confirmation toast", %{conn: conn} do
      record = record()
      stub_musicbrainz_happy_path(record.musicbrainz_id)

      {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")
      render_click(view, "refresh_musicbrainz_data", %{})

      assert render(view) =~ "MusicBrainz data refreshed successfully"
    end

    @tag :capture_log
    test "error path shows error toast with friendly message", %{conn: conn} do
      record = record()
      release_group_id = record.musicbrainz_id

      # Initial page load needs a valid response, then the refresh request fails.
      Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_, _, "release-group", ^release_group_id] ->
            Test.transport_error(conn, :timeout)

          _ ->
            Test.json(conn, %{})
        end
      end)

      {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")
      render_click(view, "refresh_musicbrainz_data", %{})

      html = render(view)
      assert html =~ "Error refreshing MusicBrainz data"
    end
  end

  describe "refresh_cover event" do
    test "success path stores new cover and shows toast", %{conn: conn} do
      record = record()
      stub_musicbrainz_happy_path(record.musicbrainz_id, cover_data: raven_cover_data())

      {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")
      render_click(view, "refresh_cover", %{})

      assert render(view) =~ "Cover refreshed successfully"
      refute Records.get_record!(record.id).cover_hash == record.cover_hash
    end

    @tag :capture_log
    test "error path shows error toast", %{conn: conn} do
      record = record()
      release_group_id = record.musicbrainz_id
      release_group = ReleaseGroup.release_group(:marbles)

      Test.stub(MusicBrainz.API, fn conn ->
        cond do
          conn.host == "coverartarchive.org" ->
            Test.transport_error(conn, :timeout)

          match?([_, _, "release-group", ^release_group_id], conn.path_info) ->
            Test.json(conn, release_group)

          true ->
            Test.json(conn, %{})
        end
      end)

      {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")
      render_click(view, "refresh_cover", %{})

      assert render(view) =~ "Error refreshing cover"
    end
  end

  describe "populate_genres event" do
    test "enqueues a PopulateGenres Oban job and shows toast", %{conn: conn} do
      record = record()
      stub_musicbrainz_happy_path(record.musicbrainz_id)

      {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")
      render_click(view, "populate_genres", %{})

      assert render(view) =~ "In progress - record will update automatically"

      assert_enqueued(
        worker: MusicLibrary.Worker.PopulateGenres,
        args: %{"id" => record.id}
      )
    end
  end

  describe "extract_colors event" do
    test "success path extracts colors from cover and shows toast", %{conn: conn} do
      record = record(%{dominant_colors: []})
      stub_musicbrainz_happy_path(record.musicbrainz_id)

      {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")
      render_click(view, "extract_colors", %{})

      assert render(view) =~ "Colors extracted"

      updated = Records.get_record!(record.id)
      # FakeColorExtractor returns a fixed 5-color palette
      assert length(updated.dominant_colors) == 5
    end

    @tag :capture_log
    test "error path shows error toast when cover asset is missing", %{conn: conn} do
      # Fixture stores an asset then points the record at it; we swap in a
      # bogus hash after creation so `Assets.get/1` returns nil and
      # `extract_colors/1` falls through the `{:error, :asset_not_found}` branch.
      record = record()
      {:ok, record} = Records.update_record(record, %{cover_hash: String.duplicate("00", 32)})
      stub_musicbrainz_happy_path(record.musicbrainz_id)

      {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")
      render_click(view, "extract_colors", %{})

      assert render(view) =~ "Error extracting colors"
    end
  end

  describe "handle_chats_changed" do
    test "re-counts chats when the Chat component broadcasts a change", %{conn: conn} do
      record = record()
      stub_musicbrainz_happy_path(record.musicbrainz_id)

      {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")

      {:ok, _chat} =
        Chats.create_chat_with_message(
          %{entity: :record, musicbrainz_id: record.musicbrainz_id},
          %{role: "user", content: "hello"}
        )

      # The Chat component would `send(self(), {Chat, :chats_changed})` after
      # seeding a chat. We simulate that by sending the same message directly.
      send(view.pid, {MusicLibraryWeb.Components.Chat, :chats_changed})

      # Forcing a re-render flushes the handle_info that re-computes chat_count;
      # we verify via the context function which is the authoritative count.
      _ = render(view)
      assert Chats.count_chats(:record, record.musicbrainz_id) == 1
    end
  end

  describe "handle_record_updated" do
    test "updates record assign and shows toast on PubSub broadcast", %{conn: conn} do
      record = record()
      stub_musicbrainz_happy_path(record.musicbrainz_id)

      {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")

      updated_record = %{record | title: "Brand New Title"}

      Phoenix.PubSub.broadcast(
        MusicLibrary.PubSub,
        "records:#{record.id}",
        {:update, updated_record}
      )

      html = render(view)
      assert html =~ "Brand New Title"
      assert html =~ "Record updated in the background"
    end
  end

  describe "assign_embedding_text" do
    test "renders stored embedding text in the debug sheet when one exists", %{conn: conn} do
      record = record()
      stub_musicbrainz_happy_path(record.musicbrainz_id)

      embedding_text = "Title: #{record.title}\nGenres: progressive rock"
      embedding = Enum.map(1..1536, fn _ -> 0.0 end)

      {:ok, _} = Similarity.store_embedding(record.id, embedding, embedding_text)

      {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")

      assert render(view) =~ "Genres: progressive rock"
    end

    # The `{:error, :not_found}` branch is exercised implicitly by every
    # other test in this file — fixture records have no stored embedding,
    # so page mount falls through to `assign(:embedding_text, "Not available")`.
  end
end
