defmodule MusicLibraryWeb.CollectionLive.ShowTest do
  use MusicLibraryWeb.ConnCase

  import Phoenix.LiveViewTest,
    only: [
      render_click: 1,
      render_hook: 3,
      render_submit: 1,
      form: 3,
      element: 2
    ]

  import MusicLibrary.Fixtures.Records
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias BraveSearch.API, as: BraveSearchAPI
  alias MusicBrainz.Fixtures
  alias MusicLibrary.Assets.{Image, Transform}
  alias MusicLibrary.Notes
  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record
  alias Phoenix.PubSub

  describe "Edit record from show page" do
    test "can navigate to the record edit form", %{conn: conn} do
      record = record()

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> assert_has("a", "Edit")
      |> click_link("Edit")
      |> assert_path(~p"/collection/#{record}/show/edit")
    end
  end

  describe "Show record" do
    test "includes all needed information", %{conn: conn} do
      record = record()
      transform = %Transform{hash: record.cover_hash, width: nil}
      payload = Transform.encode!(transform)
      cover_url = ~p"/assets/#{payload}"

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()
        |> assert_has("h2", escape(record.title))
        |> assert_has("p", record.release_date)
        |> assert_has("p", format_label(record.format))
        |> assert_has("p", type_label(record.type))
        |> assert_has("dd", Record.format_as_date(record.purchased_at))
        |> assert_has("code#record-#{record.id}", record.id)
        |> assert_has("code#mb-#{record.musicbrainz_id}", record.musicbrainz_id)
        |> assert_has("span", "Multi")
        |> assert_has("span", "03/05/2004")
        |> assert_has("span", "🇬🇧")
        |> assert_has("p", Record.format_as_date(record.inserted_at))
        |> assert_has("p", Record.format_as_date(record.updated_at))
        |> assert_has("img[src='#{cover_url}']")

      for artist <- record.artists do
        assert_has(session, "a", escape(artist.name))
      end

      for genre <- record.genres do
        assert_has(session, "a", genre)
      end
    end
  end

  describe "Delete record" do
    test "deletes the record and navigates back to collection", %{conn: conn} do
      record = record()
      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      conn
      |> visit(~p"/collection/#{record.id}")
      |> click_link("a[data-confirm='Are you sure?']", "Delete")
      |> assert_path(~p"/collection")

      assert_raise Ecto.NoResultsError, fn ->
        Records.get_record!(record.id)
      end
    end
  end

  describe "handle_info({:update, record}) with live_action guard" do
    test "updates record when showing (live_action is :show)", %{conn: conn} do
      record = record()

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      updated_record = %{record | title: "Background Updated Title"}

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()

      PubSub.broadcast(
        MusicLibrary.PubSub,
        "records:#{record.id}",
        {:update, updated_record}
      )

      session
      |> assert_has("*", text: "Background Updated Title", timeout: 200)
      |> assert_has("#toast-group", text: "Record updated in the background")
    end

    test "skips update when editing and shows warning toast", %{conn: conn} do
      record = record()

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      updated_record = %{record | title: "Should Not Appear"}

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()
        |> click_link("Edit")

      PubSub.broadcast(
        MusicLibrary.PubSub,
        "records:#{record.id}",
        {:update, updated_record}
      )

      session
      |> refute_has("h2", text: "Should Not Appear")
      |> assert_has(
        "#toast-group",
        text:
          "Record was updated in the background. Your edits may be stale — save and re-open to see the latest data."
      )
    end

    test "no-ops when broadcasted record has mismatched ID", %{conn: conn} do
      record = record()
      other_record = record()

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()

      PubSub.broadcast(
        MusicLibrary.PubSub,
        "records:#{record.id}",
        {:update, other_record}
      )

      session
      |> assert_has("h2", text: escape(record.title))
      |> refute_has("#toast-group", text: "Record updated in the background")
    end
  end

  describe "RecordForm genre editing" do
    setup do
      artist_name = "Steven Wilson"
      record = record_with_artist(artist_name)

      release_response = Fixtures.Release.release(:marbles)

      # Stub MusicBrainz API for the show page release data
      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      %{record: record}
    end

    test "shows genre search suggestions when typing", %{conn: conn, record: record} do
      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()
        |> click_link("Edit")

      # Trigger the genre search via the hook
      session =
        unwrap(session, fn view ->
          view
          |> element("#genre-input-container")
          |> render_hook("search_genres", %{"value" => "prog"})
        end)

      assert_has(session, "#genre-suggestions")
    end

    test "adding a new normalized genre shows a badge", %{conn: conn, record: record} do
      existing_genres = record.genres
      new_genre = "test-genre"
      refute new_genre in existing_genres

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()
        |> click_link("Edit")
        |> unwrap(fn view ->
          view
          |> element("#genre-input-container")
          |> render_hook("add_genre", %{"genre" => new_genre})
        end)

      # The new genre should appear in a badge element, normalized to lowercase
      assert_has(session, "[phx-click='remove_genre']", String.downcase(new_genre))
    end

    test "adding a duplicate genre does not create a second badge", %{conn: conn, record: record} do
      [existing_genre | _] = record.genres

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()
        |> click_link("Edit")
        |> unwrap(fn view ->
          view
          |> element("#genre-input-container")
          |> render_hook("add_genre", %{"genre" => existing_genre})
        end)

      # The genre should appear exactly once (no duplicate badge)
      assert_has(session, "[phx-click='remove_genre']", existing_genre, count: 1)
    end

    test "removing a genre hides its badge", %{conn: conn, record: record} do
      [genre_to_remove | _] = record.genres

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()
        |> click_link("Edit")

      # Verify the genre badge exists before removal
      assert_has(session, "[phx-click='remove_genre']", genre_to_remove)

      # Click the remove icon on the genre badge
      session =
        unwrap(session, fn view ->
          view
          |> element("[phx-click='remove_genre'][phx-value-genre='#{genre_to_remove}']")
          |> render_click()
        end)

      # The badge should now be gone
      refute_has(session, "[phx-click='remove_genre']", genre_to_remove)
    end

    test "persists genre changes when saving the form", %{conn: conn, record: record} do
      new_genre = "test-persisted-genre"
      refute new_genre in record.genres

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()
        |> click_link("Edit")
        |> unwrap(fn view ->
          view
          |> element("#genre-input-container")
          |> render_hook("add_genre", %{"genre" => new_genre})
        end)

      assert_has(session, "[phx-click='remove_genre']", String.downcase(new_genre))

      session
      |> click_button("#record-form button", "Save")
      |> assert_has("p", "Record updated successfully")

      # Verify the genre was actually persisted
      updated_record = MusicLibrary.Records.get_record!(record.id)
      assert String.downcase(new_genre) in updated_record.genres
    end
  end

  describe "RecordForm cover search" do
    setup do
      Req.Test.set_req_test_to_shared()

      record = record()

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      on_exit(fn ->
        Req.Test.stub(BraveSearchAPI, nil)
      end)

      %{record: record}
    end

    test "shows cover search results on success", %{conn: conn, record: record} do
      Req.Test.stub(BraveSearchAPI, fn conn ->
        Req.Test.json(conn, %{
          "results" => [
            %{
              "thumbnail" => %{"src" => "https://example.com/thumb1.jpg"},
              "properties" => %{
                "url" => "https://example.com/full1.jpg",
                "width" => 800,
                "height" => 600
              },
              "title" => "Test Cover 1",
              "source" => "example.com"
            },
            %{
              "thumbnail" => %{"src" => "https://example.com/thumb2.jpg"},
              "properties" => %{
                "url" => "https://example.com/full2.jpg",
                "width" => 1024,
                "height" => 1024
              },
              "title" => "Test Cover 2",
              "source" => "example.com"
            }
          ]
        })
      end)

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> click_link("Edit")
      |> click_button("#cover-search-button", "Search")
      |> render_async()
      |> assert_has("#cover-search-results")
      |> assert_has("img[alt='Test Cover 1']")
      |> assert_has("img[alt='Test Cover 2']")
    end

    @tag :capture_log
    test "shows friendly error message on search failure", %{conn: conn, record: record} do
      Req.Test.stub(BraveSearchAPI, fn conn ->
        conn
        |> Plug.Conn.put_status(429)
        |> Req.Test.json(%{"error" => "Rate limit exceeded"})
      end)

      conn
      |> visit(~p"/collection/#{record.id}")
      |> render_async()
      |> click_link("Edit")
      |> click_button("#cover-search-button", "Search")
      |> render_async()
      |> assert_has("p", "Search failed")
    end

    test "selecting a cover result downloads and persists the cover", %{
      conn: conn,
      record: record
    } do
      original_hash = record.cover_hash

      Req.Test.stub(BraveSearchAPI, fn
        conn when conn.request_path == "/res/v1/images/search" ->
          Req.Test.json(conn, %{
            "results" => [
              %{
                "thumbnail" => %{"src" => "https://example.com/thumb1.jpg"},
                "properties" => %{
                  "url" => "https://example.com/full1.jpg",
                  "width" => 800,
                  "height" => 600
                },
                "title" => "New Cover",
                "source" => "example.com"
              }
            ]
          })

        conn ->
          Plug.Conn.send_resp(conn, 200, Image.fallback_data())
      end)

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()
        |> click_link("Edit")
        |> click_button("#cover-search-button", "Search")
        |> render_async()
        |> assert_has("#cover-search-results")

      # Click the first cover search result
      session =
        unwrap(session, fn view ->
          view
          |> element("#cover-search-results button:first-child")
          |> render_click()
        end)
        |> render_async()

      assert_has(session, "p", "Cover art updated successfully")

      # Verify the cover hash actually changed
      updated_record = MusicLibrary.Records.get_record!(record.id)
      assert updated_record.cover_hash != original_hash

      # Verify an asset exists for the new hash
      asset = MusicLibrary.Assets.get(updated_record.cover_hash)
      assert asset != nil
    end
  end

  describe "Notes component" do
    setup do
      record = record()

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      %{record: record}
    end

    test "creates a new note through the Notes component form", %{conn: conn, record: record} do
      # No note exists yet
      assert Notes.get_note(:record, record.musicbrainz_id) == nil

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()

      # The Notes component starts in "edit" mode when no note exists.
      # Submit the notes form (always in the DOM, even when the Fluxon sheet is hidden).
      session =
        unwrap(session, fn view ->
          view
          |> form("#notes-form", %{"note" => %{"content" => "My test note content"}})
          |> render_submit()
        end)

      assert_has(session, "#toast-group", text: "Note created successfully")

      # Verify persistence
      fetched = Notes.get_note(:record, record.musicbrainz_id)
      assert fetched.content == "My test note content"
    end

    test "renders an existing note in read mode", %{conn: conn, record: record} do
      # Pre-create a note
      {:ok, _note} =
        Notes.create_note(
          %MusicLibrary.Notes.Note{entity: :record, musicbrainz_id: record.musicbrainz_id},
          %{"content" => "Existing note content"}
        )

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()

      # The Read tab panel contains the rendered note content
      assert_has(session, "#read-panel article", text: "Existing note content")
    end

    test "updates existing note content through the Notes component form", %{
      conn: conn,
      record: record
    } do
      # Pre-create a note
      {:ok, _note} =
        Notes.create_note(
          %MusicLibrary.Notes.Note{entity: :record, musicbrainz_id: record.musicbrainz_id},
          %{"content" => "Original content"}
        )

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> render_async()

      # Switch to "edit" tab inside the Notes component
      session =
        unwrap(session, fn view ->
          view
          |> element("button[aria-controls='edit-panel']")
          |> render_click()
        end)

      # Submit updated content through the form
      session
      |> unwrap(fn view ->
        view
        |> form("#notes-form", %{"note" => %{"content" => "Updated content"}})
        |> render_submit()
      end)
      |> assert_has("#toast-group", text: "Note updated successfully")

      # Verify persistence
      fetched = Notes.get_note(:record, record.musicbrainz_id)
      assert fetched.content == "Updated content"
    end
  end

  describe "Side panel" do
    test "shows a record's tracks", %{conn: conn} do
      record = record()

      release_response = Fixtures.Release.release(:marbles)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, release_response)
      end)

      session =
        conn
        |> visit(~p"/collection/#{record.id}")
        |> assert_has("button", "Show Tracks")
        |> render_async()
        |> assert_has("a", "Connect Last.fm")

      release =
        MusicBrainz.Release.from_api_response(release_response)

      for medium <- release.media do
        session
        |> within("#disc-#{medium.number}", fn inner_session ->
          for track <- medium.tracks do
            inner_session
            |> assert_has("li", escape(track.title))
          end

          inner_session
        end)
      end
    end
  end
end
