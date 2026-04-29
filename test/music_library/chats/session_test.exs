defmodule MusicLibrary.Chats.SessionTest do
  use MusicLibrary.DataCase, async: false

  import MusicLibrary.ChatsFixtures

  alias MusicLibrary.Chats.Session

  @instructions """
  # IDENTITY

  You are a knowledgeable music assistant.


  # YOUR TASK

  Answer questions about the album the user is currently viewing. Use the provided album information as your primary reference.

  Album information:
  Radiohead - OK Computer (1997). Alternative rock masterpiece.

  # APPROACH AND TONE

  - Use web search to find additional up-to-date information when helpful.
  - Be concise and accurate. When unsure, say so.
  - Include links when they add genuine value, and at least one per response (but not one per paragraph).
  - Vary your response style and structure. Don't repeat information already discussed in the conversation.
  - Refer back to earlier points naturally instead of restating them.
  - **DO NOT INCLUDE A SUMMARY AT THE END OF YOUR MESSAGE.**
  - **DO NOT PROVIDE SUGGESTIONS OR ASK QUESTIONS AS A MEAN TO CONTINUE THE CONVERSATION.**
  - **DO NOT GIVE POINTERS ON WHAT TO DO AT THE END OF THE MESSAGE**
  """

  describe "get_history/1" do
    test "for existing chats" do
      chat = chat_fixture()

      params = %{
        chat_id: chat.id,
        instructions: @instructions
      }

      assert {:ok, _pid} = Session.start_link(params)
      assert chat == Session.get_history(chat.id)
    end

    test "for non existing chats" do
      chat_id = Ecto.UUID.generate()

      params = %{
        chat_id: chat_id,
        instructions: @instructions
      }

      assert {:ok, _pid} = Session.start_link(params)
      assert nil == Session.get_history(chat_id)
    end
  end

  describe "send_message/2" do
    test "for existing chats appends the message" do
      chat = chat_fixture()

      params = %{
        chat_id: chat.id,
        instructions: @instructions
      }

      assert {:ok, pid} = Session.start_link(params)

      stub_default_reply(pid)

      assert {:ok, message} = Session.send_message(chat.id, "some message")

      assert message.content == "some message"
      assert message.chat_id == chat.id

      updated_chat = Session.get_history(chat.id)

      assert message in updated_chat.messages
    end

    test "for non existing chats creates the chat with the message" do
      chat_id = Ecto.UUID.generate()

      params = %{
        chat_id: chat_id,
        new_chat_params: %{
          entity: :record,
          musicbrainz_id: Ecto.UUID.generate()
        },
        instructions: @instructions
      }

      assert {:ok, pid} = Session.start_link(params)

      stub_default_reply(pid)

      assert {:ok, message} = Session.send_message(chat_id, "some message")
      assert :idle == Session.status(chat_id)

      assert message.content == "some message"
      assert message.chat_id == chat_id

      chat = Session.get_history(chat_id)
      assert [^message | _reply] = chat.messages
    end
  end

  describe "getting replies from the LLM" do
    test "supplies the necessary data" do
      chat = chat_fixture()

      params = %{
        chat_id: chat.id,
        instructions: @instructions
      }

      assert {:ok, pid} = Session.start_link(params)

      stub_and_allow(pid, fn conn ->
        assert conn.request_path == "/v1/responses"
        assert conn.params["instructions"] == @instructions

        assert conn.params["input"] == [
                 %{"content" => "message content", "role" => "user"},
                 %{"content" => "is this really a masterpiece?", "role" => "user"}
               ]

        body = delta_chunk("yes it is") <> completed_chunk()

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, _message} = Session.send_message(chat.id, "is this really a masterpiece?")

      assert :idle == Session.status(chat.id)
    end

    test "writes the received message to the database" do
      chat = chat_fixture()

      params = %{
        chat_id: chat.id,
        instructions: @instructions
      }

      assert {:ok, pid} = Session.start_link(params)

      stub_and_allow(pid, fn conn ->
        assert conn.request_path == "/v1/responses"
        assert conn.params["instructions"] == @instructions

        assert conn.params["input"] == [
                 %{"content" => "message content", "role" => "user"},
                 %{"content" => "is this really a masterpiece?", "role" => "user"}
               ]

        body = delta_chunk("yes it is, ") <> delta_chunk("i love it") <> completed_chunk()

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      assert {:ok, _message} = Session.send_message(chat.id, "is this really a masterpiece?")

      assert :idle == Session.status(chat.id)

      new_chat = Session.get_history(chat.id)

      assert 3 == Enum.count(new_chat.messages)
    end
  end

  describe "stream error handling" do
    @tag :capture_log
    test "retryable HTTP error enters :failed state" do
      chat = chat_fixture()

      params = %{chat_id: chat.id, instructions: @instructions}
      assert {:ok, pid} = Session.start_link(params)

      stub_http_error(pid, 500)

      assert {:ok, message} = Session.send_message(chat.id, "hello")

      assert :failed == Session.status(chat.id)

      # While recovering, send_message is rejected
      assert {:error, :busy} = Session.send_message(chat.id, "are you there?")

      # get_history still works
      chat = Session.get_history(chat.id)
      assert [_message2, ^message] = chat.messages
    end

    test "non-retryable HTTP error returns to :idle state" do
      chat = chat_fixture()

      params = %{chat_id: chat.id, instructions: @instructions}
      assert {:ok, pid} = Session.start_link(params)

      stub_http_error(pid, 401)

      assert :idle == Session.status(chat.id)

      assert {:ok, _message} = Session.send_message(chat.id, "hello")

      # After non-retryable error, session is immediately usable again
      stub_default_reply(pid)
      assert {:ok, _message} = Session.send_message(chat.id, "try again")
    end

    test "SSE mid-stream error returns to :idle state" do
      chat = chat_fixture()

      params = %{chat_id: chat.id, instructions: @instructions}
      assert {:ok, pid} = Session.start_link(params)

      stub_and_allow(pid, fn conn ->
        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, sse_error_chunk())
      end)

      assert :idle == Session.status(chat.id)

      assert {:ok, _message} = Session.send_message(chat.id, "hello")

      # SSE errors are non-retryable — session is back in :idle
      stub_default_reply(pid)
      assert {:ok, _message} = Session.send_message(chat.id, "try again")
    end
  end

  describe "broadcasted events" do
    test "sends events for the entire state lifecycle" do
      chat = chat_fixture()

      params = %{
        chat_id: chat.id,
        instructions: @instructions
      }

      assert {:ok, pid} = Session.start_link(params)

      stub_and_allow(pid, fn conn ->
        assert conn.request_path == "/v1/responses"
        assert conn.params["instructions"] == @instructions

        assert conn.params["input"] == [
                 %{"content" => "message content", "role" => "user"},
                 %{"content" => "is this really a masterpiece?", "role" => "user"}
               ]

        body = delta_chunk("yes it is, ") <> delta_chunk("i love it") <> completed_chunk()

        conn
        |> Plug.Conn.put_resp_content_type("text/event-stream")
        |> Plug.Conn.send_resp(200, body)
      end)

      Session.subscribe(chat.id)

      assert {:ok, message} = Session.send_message(chat.id, "is this really a masterpiece?")
      chat = %{chat | messages: chat.messages ++ [message]}

      assert :idle == Session.status(chat.id)

      chat_with_llm_response = Session.get_history(chat.id)

      assert_received {Session, %{status: :streaming, chat: ^chat}}
      assert_received {Session, %{status: :chunk_received, chunk: "yes it is, "}}
      assert_received {Session, %{status: :chunk_received, chunk: "i love it"}}
      assert_received {Session, %{status: :idle, chat: ^chat_with_llm_response}}
    end
  end

  defp stub_and_allow(pid, callback) do
    Req.Test.stub(OpenAI.API, callback)
    Req.Test.allow(OpenAI.API, self(), pid)
  end

  defp stub_default_reply(pid) do
    stub_and_allow(pid, fn conn ->
      body = delta_chunk("hi") <> completed_chunk()

      conn
      |> Plug.Conn.put_resp_content_type("text/event-stream")
      |> Plug.Conn.send_resp(200, body)
    end)
  end

  defp stub_http_error(pid, status) do
    stub_and_allow(pid, fn conn ->
      conn
      |> Plug.Conn.put_resp_content_type("application/json")
      |> Plug.Conn.send_resp(status, Jason.encode!(%{error: %{message: "error"}}))
    end)
  end

  defp delta_chunk(message) do
    "data: #{JSON.encode!(%{"type" => "response.output_text.delta", "delta" => message})}\n\n"
  end

  defp completed_chunk do
    "data: #{JSON.encode!(%{"type" => "response.completed"})}\n\n"
  end

  defp sse_error_chunk do
    "data: #{JSON.encode!(%{"type" => "response.failed", "response" => %{"error" => %{"message" => "something went wrong"}}})}\n\n"
  end
end
