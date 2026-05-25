defmodule MusicLibraryWeb.Components.ChatTest do
  use MusicLibraryWeb.ConnCase, async: false

  import MusicLibrary.Fixtures.Records

  import Phoenix.LiveViewTest,
    only: [element: 2, form: 3, live: 2, render: 1, render_click: 1, render_submit: 1]

  alias MusicBrainz.Fixtures.Release, as: ReleaseFixtures
  alias MusicBrainz.Fixtures.ReleaseGroup
  alias MusicLibrary.Chats
  alias MusicLibraryWeb.Components.Chat
  alias Req.Test

  @component_id "record-chat"

  setup do
    # Some tests intentionally trigger the streaming pipeline which calls
    # `OpenAI.API`. A default stub that returns an empty SSE stream prevents
    # Req.Test from raising inside the supervised Task process and keeps
    # test output noise-free. Individual tests can override this as needed.
    Test.stub(OpenAI.API, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("text/event-stream")
      |> Plug.Conn.send_resp(
        200,
        ~s(data: {"type":"response.completed"}\n\n)
      )
    end)

    :ok
  end

  defp stub_musicbrainz_happy_path(release_group_id) do
    release_group = ReleaseGroup.release_group(:marbles)
    release = ReleaseFixtures.release(:marbles)

    Test.stub(MusicBrainz.API, fn conn ->
      cond do
        conn.host == "coverartarchive.org" ->
          Plug.Conn.send_resp(conn, 200, marbles_cover_data())

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

  defp setup_record do
    record = record()
    stub_musicbrainz_happy_path(record.musicbrainz_id)
    record
  end

  defp mount_view(conn, record) do
    {:ok, view, _html} = live(conn, ~p"/collection/#{record.id}")
    view
  end

  defp seed_chat(record, content \\ "Tell me about this album") do
    {:ok, chat} =
      Chats.create_chat_with_message(
        %{entity: :record, musicbrainz_id: record.musicbrainz_id},
        %{role: "user", content: content}
      )

    chat
  end

  defp send_component_update(view, updates) do
    Phoenix.LiveView.send_update(view.pid, Chat, [id: @component_id] ++ updates)
  end

  describe "update/2 streaming state transitions" do
    test "chunk clause appends to the streaming doc", %{conn: conn} do
      record = setup_record()
      view = mount_view(conn, record)

      send_component_update(view, chunk: "Hello ")
      send_component_update(view, chunk: "world")
      html = render(view)

      assert html =~ "Hello world"
    end

    test "done clause finalizes the assistant message and clears loading", %{conn: conn} do
      record = setup_record()
      # Seed the chat before mount so the component picks up `has_history`
      # and we have a persisted `Chat` to write the assistant message to.
      chat = seed_chat(record, "User prompt")
      view = mount_view(conn, record)

      # Enter active view by selecting the seeded chat, so the active-view
      # render path (where the streaming doc and messages render) is active.
      view
      |> element("button[phx-click='select_chat'][phx-value-id='#{chat.id}']")
      |> render_click()

      # Drive the component directly into a mid-stream state, bypassing the
      # Task.Supervisor streaming pipeline (which is exercised in the
      # send_message test).
      send_component_update(view, loading: true)
      send_component_update(view, chunk: "Great album.")
      send_component_update(view, done: true)

      html = render(view)

      refute html =~ "Thinking..."
      assert html =~ "Great album."

      reloaded = Chats.get_chat!(chat.id)
      assistant_messages = Enum.filter(reloaded.messages, &(&1.role == "assistant"))
      assert [%{content: "Great album."}] = assistant_messages
    end

    test "error clause surfaces the error and a retry button", %{conn: conn} do
      record = setup_record()
      view = mount_view(conn, record)

      send_component_update(view, error: "Something went wrong. Please try again.")
      html = render(view)

      assert html =~ "Something went wrong. Please try again."
      assert html =~ "phx-click=\"retry\""
    end
  end

  describe "send_message event" do
    @tag :capture_log
    test "appends the user message and persists a chat row", %{conn: conn} do
      record = setup_record()
      view = mount_view(conn, record)

      view
      |> form("##{@component_id}-form", %{"message" => "What is this album about?"})
      |> render_submit()

      html = render(view)
      assert html =~ "What is this album about?"

      # A chat is persisted with the user message and derived topic.
      assert [chat] = Chats.list_chats(:record, record.musicbrainz_id)
      assert chat.topic == "What is this album about?"
    end

    test "empty message submission is a no-op", %{conn: conn} do
      record = setup_record()
      view = mount_view(conn, record)

      view
      |> form("##{@component_id}-form", %{"message" => ""})
      |> render_submit()

      assert Chats.list_chats(:record, record.musicbrainz_id) == []
    end

    @tag :capture_log
    test "streaming error propagates to the component as user-facing text", %{conn: conn} do
      record = setup_record()

      Test.stub(OpenAI.API, fn conn ->
        Plug.Conn.send_resp(conn, 500, JSON.encode!(%{"error" => "internal server error"}))
      end)

      view = mount_view(conn, record)

      view
      |> form("##{@component_id}-form", %{"message" => "Trigger an error"})
      |> render_submit()

      # Req.Test stubs respond synchronously, so the Task completes before
      # we render again — the component has already processed `send_update`
      # with `error:`.
      assert render(view) =~ "Something went wrong. Please try again."
    end
  end

  describe "new_chat event" do
    test "clears messages and switches to active view", %{conn: conn} do
      record = setup_record()
      chat = seed_chat(record)
      view = mount_view(conn, record)

      # Initial view is :list because the component detected existing chats.
      view
      |> element("button[phx-click='select_chat'][phx-value-id='#{chat.id}']")
      |> render_click()

      assert render(view) =~ "Tell me about this album"

      view
      |> element("button[phx-click='new_chat']")
      |> render_click()

      html = render(view)
      # The empty-prompt copy from CollectionLive.Show is shown again.
      assert html =~ "Ask anything about this album"
    end
  end

  describe "show_chat_list event" do
    test "renders the persisted chats in the list view", %{conn: conn} do
      record = setup_record()
      seed_chat(record, "First prompt")
      seed_chat(record, "Second prompt")
      view = mount_view(conn, record)

      # Already on list view at mount, but exercise the event explicitly by
      # selecting a chat then clicking the history button.
      chat = List.first(Chats.list_chats(:record, record.musicbrainz_id))

      view
      |> element("button[phx-click='select_chat'][phx-value-id='#{chat.id}']")
      |> render_click()

      view
      |> element("button[phx-click='show_chat_list']")
      |> render_click()

      html = render(view)
      assert html =~ "First prompt"
      assert html =~ "Second prompt"
      assert html =~ "Chat history"
    end
  end

  describe "select_chat event" do
    test "loads the selected chat's messages", %{conn: conn} do
      record = setup_record()
      chat = seed_chat(record, "Original question")

      {:ok, _assistant} =
        Chats.add_message(chat, %{role: "assistant", content: "Original answer"})

      view = mount_view(conn, record)

      view
      |> element("button[phx-click='select_chat'][phx-value-id='#{chat.id}']")
      |> render_click()

      html = render(view)
      assert html =~ "Original question"
      assert html =~ "Original answer"
    end
  end

  describe "delete_chat event" do
    test "removes the active chat and clears its messages", %{conn: conn} do
      record = setup_record()
      chat = seed_chat(record, "Goodbye chat")
      {:ok, _assistant} = Chats.add_message(chat, %{role: "assistant", content: "Some reply"})
      view = mount_view(conn, record)

      # Select the chat (transitions into active view), then re-open the list
      # to reach the delete button (only rendered in list view).
      view
      |> element("button[phx-click='select_chat'][phx-value-id='#{chat.id}']")
      |> render_click()

      view
      |> element("button[phx-click='show_chat_list']")
      |> render_click()

      view
      |> element("button[phx-click='delete_chat'][phx-value-id='#{chat.id}']")
      |> render_click()

      assert_raise Ecto.NoResultsError, fn -> Chats.get_chat!(chat.id) end
      assert Chats.list_chats(:record, record.musicbrainz_id) == []

      # The active-chat branch of `delete_chat` clears `chat` and `messages`
      # — verify by starting a new chat and confirming the empty state, not
      # the stale assistant reply.
      view
      |> element("button[phx-click='new_chat']")
      |> render_click()

      html = render(view)
      assert html =~ "Ask anything about this album"
      refute html =~ "Some reply"
    end

    test "deleting a non-active chat leaves the remaining chats in the list", %{conn: conn} do
      record = setup_record()
      _chat_a = seed_chat(record, "Keep me")
      chat_b = seed_chat(record, "Delete me")
      view = mount_view(conn, record)

      # Already on list view; delete chat B directly from the list.
      view
      |> element("button[phx-click='delete_chat'][phx-value-id='#{chat_b.id}']")
      |> render_click()

      assert_raise Ecto.NoResultsError, fn -> Chats.get_chat!(chat_b.id) end
      html = render(view)
      assert html =~ "Keep me"
      refute html =~ "Delete me"
    end
  end

  describe "retry event" do
    test "clears the error when the last message is not from the user", %{conn: conn} do
      record = setup_record()
      view = mount_view(conn, record)

      send_component_update(view,
        error: "Something went wrong. Please try again.",
        messages: []
      )

      assert render(view) =~ "Something went wrong. Please try again."

      view
      |> element("button[phx-click='retry']")
      |> render_click()

      refute render(view) =~ "Something went wrong. Please try again."
    end

    @tag :capture_log
    test "re-sends the last user message when retry is clicked", %{conn: conn} do
      # Mount without pre-seeded chats so the component starts in :active
      # view — the error UI and retry button only render in that view.
      record = setup_record()
      view = mount_view(conn, record)

      chat = seed_chat(record, "Resend me")

      # The regular-assigns clause of `update/2` and the error-clause pattern
      # match on different keys — splitting the calls avoids the error clause
      # consuming the whole map and dropping `chat`/`messages`.
      send_component_update(view,
        chat: chat,
        messages: [%{role: "user", content: "Resend me"}]
      )

      send_component_update(view, error: "Something went wrong. Please try again.")

      assert render(view) =~ "Something went wrong. Please try again."

      view
      |> element("button[phx-click='retry']")
      |> render_click()

      html = render(view)
      refute html =~ "Something went wrong. Please try again."
      assert html =~ "Resend me"

      # `retry` drops the last user message, then `do_send_message/2`
      # re-persists it via `Chats.add_message/2` — so the seeded chat
      # contains two user rows with the same content.
      reloaded = Chats.get_chat!(chat.id)
      user_messages = Enum.filter(reloaded.messages, &(&1.role == "user"))
      assert Enum.count_until(user_messages, 3) == 2
    end
  end
end
