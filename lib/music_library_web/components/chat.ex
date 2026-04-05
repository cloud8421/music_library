defmodule MusicLibraryWeb.Components.Chat do
  use MusicLibraryWeb, :live_component

  require Logger

  alias MusicLibrary.Chats
  alias MusicLibraryWeb.Markdown

  def open(id), do: Fluxon.open_dialog(id)

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:current_response, "")
     |> assign(:loading, false)
     |> assign(:error, nil)
     |> assign(:view, :active)
     |> assign(:chat, nil)
     |> assign(:chats, [])
     |> assign(:streaming_doc, nil)
     |> assign(:has_history, false)}
  end

  @impl true
  def update(%{chunk: chunk}, socket) do
    doc = socket.assigns.streaming_doc || Markdown.new_streaming_doc(link_target: "_blank")

    {:ok,
     socket
     |> update(:current_response, &(&1 <> chunk))
     |> assign(:streaming_doc, MDEx.Document.put_markdown(doc, chunk))}
  end

  def update(%{done: true}, socket) do
    completed_message = %{role: "assistant", content: socket.assigns.current_response}

    save_assistant_message(socket.assigns.chat, completed_message.content)

    {:ok,
     socket
     |> update(:messages, &(&1 ++ [completed_message]))
     |> assign(:current_response, "")
     |> assign(:streaming_doc, nil)
     |> assign(:loading, false)}
  end

  def update(%{error: error}, socket) do
    {:ok,
     socket
     |> assign(:error, error)
     |> assign(:loading, false)}
  end

  def update(assigns, socket) do
    socket = assign(socket, assigns)

    socket =
      if changed?(socket, :entity) or changed?(socket, :musicbrainz_id) do
        has_history = check_chat_history(socket.assigns)

        if has_history do
          chats = Chats.list_chats(socket.assigns.entity, socket.assigns.musicbrainz_id)

          socket
          |> assign(:has_history, true)
          |> assign(:chats, chats)
          |> assign(:view, :list)
        else
          socket
          |> assign(:has_history, false)
          |> assign(:view, :active)
        end
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.sheet
        id={@sheet_id}
        placement="right"
        class="flex h-full w-md flex-col sm:min-w-lg lg:min-w-2xl"
        hide_close_button
      >
        <%= if @view == :list do %>
          {render_list_view(assigns)}
        <% else %>
          {render_active_view(assigns)}
        <% end %>
      </.sheet>
      <script :type={Phoenix.LiveView.ColocatedHook} name=".ScrollBottom">
        export default {
          mounted() {
            this.scrollToBottom();
            this.observer = new MutationObserver(() => this.scrollToBottom());
            this.observer.observe(this.el, { childList: true, subtree: true, characterData: true });
          },
          updated() {
            this.scrollToBottom();
          },
          destroyed() {
            if (this.observer) this.observer.disconnect();
          },
          scrollToBottom() {
            this.el.scrollTop = this.el.scrollHeight;
          }
        }
      </script>
    </div>
    """
  end

  defp render_list_view(assigns) do
    ~H"""
    <div class="flex items-center justify-between border-b border-zinc-200 pb-4 dark:border-zinc-700">
      <h2 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
        {gettext("Chat history")}
      </h2>
      <div class="flex items-center gap-2">
        <.button size="sm" variant="soft" phx-click="new_chat" phx-target={@myself}>
          <.icon name="hero-plus" class="icon" data-slot="icon" />
          {gettext("New chat")}
        </.button>
        <.button
          size="icon-sm"
          variant="ghost"
          phx-click={Fluxon.close_dialog(@sheet_id)}
          aria-label={gettext("Close")}
        >
          <.icon name="hero-x-mark" class="icon" />
        </.button>
      </div>
    </div>

    <div class="flex-1 overflow-y-auto py-4">
      <div
        :if={@chats == []}
        class="flex h-full flex-col items-center justify-center text-center text-zinc-500 dark:text-zinc-400"
      >
        <.icon
          name="hero-chat-bubble-left-right"
          class="mb-4 size-12 text-zinc-300 dark:text-zinc-600"
        />
        <p class="text-sm font-medium">{gettext("No previous chats")}</p>
      </div>

      <div :for={chat <- @chats} class="group relative">
        <button
          phx-click="select_chat"
          phx-value-id={chat.id}
          phx-target={@myself}
          class="w-full rounded-lg p-3 text-left transition-colors hover:bg-zinc-100 dark:hover:bg-zinc-800"
        >
          <p class="truncate text-sm font-medium text-zinc-900 dark:text-zinc-100">
            {chat.topic || gettext("Untitled")}
          </p>
          <p class="mt-1 text-xs text-zinc-500 dark:text-zinc-400">
            {ngettext("%{count} message", "%{count} messages", chat.message_count)} · {Calendar.strftime(
              chat.updated_at,
              "%b %-d, %Y"
            )}
          </p>
        </button>
        <.button
          size="icon-xs"
          variant="ghost"
          color="danger"
          phx-click="delete_chat"
          phx-value-id={chat.id}
          phx-target={@myself}
          aria-label={gettext("Delete chat")}
          class="absolute top-3 right-2 opacity-0 transition-opacity group-hover:opacity-100"
        >
          <.icon name="hero-trash" class="icon" />
        </.button>
      </div>
    </div>
    """
  end

  defp render_active_view(assigns) do
    ~H"""
    <div class="flex items-center gap-2 border-b border-zinc-200 pb-4 dark:border-zinc-700">
      <h2 class="flex-1 text-lg font-semibold text-zinc-900 dark:text-zinc-100">
        {gettext("Chat about %{title}", title: @title)}
      </h2>
      <.button
        :if={@has_history}
        size="icon-sm"
        variant="ghost"
        phx-click="show_chat_list"
        phx-target={@myself}
        aria-label={gettext("Chat history")}
      >
        <.icon name="hero-clock" class="icon" />
      </.button>
      <.button
        :if={@messages != []}
        size="icon-sm"
        variant="ghost"
        phx-click="new_chat"
        phx-target={@myself}
        aria-label={gettext("New chat")}
      >
        <.icon name="hero-plus" class="icon" />
      </.button>
      <.button
        size="icon-sm"
        variant="ghost"
        phx-click={Fluxon.close_dialog(@sheet_id)}
        aria-label={gettext("Close")}
      >
        <.icon name="hero-x-mark" class="icon" />
      </.button>
    </div>

    <div
      id={"#{@id}-messages"}
      class="flex-1 space-y-4 overflow-y-auto py-4"
      phx-hook=".ScrollBottom"
    >
      <div
        :if={@messages == [] and @streaming_doc == nil}
        class="flex h-full flex-col items-center justify-center text-center text-zinc-500 dark:text-zinc-400"
      >
        <.icon
          name="hero-chat-bubble-left-right"
          class="mb-4 size-12 text-zinc-300 dark:text-zinc-600"
        />
        <p class="text-sm font-medium">{@empty_prompt}</p>
      </div>

      <div
        :for={message <- @messages}
        class={[
          "max-w-[85%] rounded-lg px-4 py-2 text-sm",
          message_classes(message.role)
        ]}
      >
        <p :if={message.role == "user"} class="whitespace-pre-wrap">{message.content}</p>
        <div
          :if={message.role == "assistant"}
          id={"chat-msg-#{message.id}"}
          class="dark:prose-invert prose prose-sm"
        >
          {raw(Markdown.to_html(message.content, link_target: "_blank"))}
        </div>
        <div :if={message.role == "assistant"} class="flex justify-end -mb-1 -mr-2">
          <.copy_to_clipboard
            target_id={"chat-msg-#{message.id}"}
            label={gettext("Copy message")}
          />
        </div>
      </div>

      <div
        :if={@streaming_doc != nil}
        class="max-w-[85%] rounded-lg bg-zinc-100 px-4 py-2 text-sm text-zinc-900 dark:bg-zinc-700 dark:text-zinc-100"
      >
        <div class="dark:prose-invert prose prose-sm">
          {raw(Markdown.streaming_to_html(@streaming_doc, link_target: "_blank"))}
        </div>
      </div>

      <div
        :if={@loading and @streaming_doc == nil}
        class="flex items-center gap-2 text-zinc-500 dark:text-zinc-400"
      >
        <.loading class="size-4" />
        <span class="text-sm">{gettext("Thinking...")}</span>
      </div>

      <div
        :if={@error}
        class="max-w-[85%] rounded-lg bg-red-50 px-4 py-2 text-sm text-red-700 dark:bg-red-900/20 dark:text-red-300"
      >
        <p>{@error}</p>
        <.button
          size="xs"
          variant="ghost"
          color="danger"
          phx-click="retry"
          phx-target={@myself}
          class="mt-2"
        >
          {gettext("Retry")}
        </.button>
      </div>
    </div>

    <div class="border-t border-zinc-200 pt-4 dark:border-zinc-700">
      <form
        id={"#{@id}-form"}
        phx-submit="send_message"
        phx-target={@myself}
        class="flex gap-2"
      >
        <.input
          name="message"
          value=""
          placeholder={@placeholder}
          class="flex-1"
          disabled={@loading}
          autocomplete="off"
        />
        <.button
          type="submit"
          variant="solid"
          size="icon"
          disabled={@loading}
          aria-label={gettext("Send message")}
        >
          <.icon name="hero-paper-airplane" class="icon" />
        </.button>
      </form>
    </div>
    """
  end

  @impl true
  def handle_event("send_message", %{"message" => ""}, socket), do: {:noreply, socket}

  def handle_event("send_message", %{"message" => text}, socket),
    do: do_send_message(socket, text)

  def handle_event("new_chat", _params, socket) do
    {:noreply,
     socket
     |> assign(:messages, [])
     |> assign(:current_response, "")
     |> assign(:streaming_doc, nil)
     |> assign(:error, nil)
     |> assign(:chat, nil)
     |> assign(:view, :active)}
  end

  def handle_event("show_chat_list", _params, socket) do
    chats = Chats.list_chats(socket.assigns.entity, socket.assigns.musicbrainz_id)

    {:noreply,
     socket
     |> assign(:chats, chats)
     |> assign(:view, :list)}
  end

  def handle_event("select_chat", %{"id" => id}, socket) do
    chat = Chats.get_chat!(id)

    {:noreply,
     socket
     |> assign(:chat, chat)
     |> assign(:messages, chat.messages)
     |> assign(:current_response, "")
     |> assign(:streaming_doc, nil)
     |> assign(:error, nil)
     |> assign(:view, :active)}
  end

  def handle_event("delete_chat", %{"id" => id}, socket) do
    chat = Chats.get_chat!(id)
    {:ok, _} = Chats.delete_chat(chat)
    send(self(), {__MODULE__, :chats_changed})

    chats = Chats.list_chats(socket.assigns.entity, socket.assigns.musicbrainz_id)

    socket =
      if socket.assigns.chat && socket.assigns.chat.id == id do
        socket
        |> assign(:chat, nil)
        |> assign(:messages, [])
        |> assign(:current_response, "")
        |> assign(:streaming_doc, nil)
        |> assign(:error, nil)
      else
        socket
      end

    {:noreply, assign(socket, :chats, chats)}
  end

  def handle_event("retry", _params, socket) do
    case List.last(socket.assigns.messages) do
      %{role: "user"} = last_message ->
        socket
        |> assign(:messages, Enum.drop(socket.assigns.messages, -1))
        |> do_send_message(last_message.content)

      _ ->
        {:noreply, assign(socket, :error, nil)}
    end
  end

  defp do_send_message(socket, text) do
    parent_pid = self()
    component_id = socket.assigns.id
    user_message = %{role: "user", content: String.trim(text)}

    messages = socket.assigns.messages ++ [user_message]
    chat_module = socket.assigns.chat_module
    chat_context = socket.assigns.chat_context

    chat = persist_user_message(socket, user_message)

    Task.Supervisor.start_child(MusicLibrary.TaskSupervisor, fn ->
      case chat_module.stream_response(messages, chat_context, fn chunk ->
             Phoenix.LiveView.send_update(parent_pid, __MODULE__,
               id: component_id,
               chunk: chunk
             )
           end) do
        :ok ->
          Phoenix.LiveView.send_update(parent_pid, __MODULE__,
            id: component_id,
            done: true
          )

        {:error, reason} ->
          Logger.error("Chat streaming error: #{reason}")

          Phoenix.LiveView.send_update(parent_pid, __MODULE__,
            id: component_id,
            error: gettext("Something went wrong. Please try again.")
          )
      end
    end)

    {:noreply,
     socket
     |> assign(:messages, messages)
     |> assign(:chat, chat)
     |> assign(:has_history, true)
     |> assign(:loading, true)
     |> assign(:current_response, "")
     |> assign(:streaming_doc, nil)
     |> assign(:error, nil)}
  end

  defp persist_user_message(socket, user_message) do
    case socket.assigns.chat do
      nil ->
        {:ok, chat} =
          Chats.create_chat_with_message(
            %{entity: socket.assigns.entity, musicbrainz_id: socket.assigns.musicbrainz_id},
            %{role: user_message.role, content: user_message.content}
          )

        send(self(), {__MODULE__, :chats_changed})
        chat

      chat ->
        {:ok, _message} =
          Chats.add_message(chat, %{role: user_message.role, content: user_message.content})

        chat
    end
  end

  defp save_assistant_message(nil, _content), do: :ok

  defp save_assistant_message(chat, content) do
    case Chats.add_message(chat, %{role: "assistant", content: content}) do
      {:ok, _message} ->
        :ok

      {:error, reason} ->
        Logger.warning("Failed to persist assistant message: #{inspect(reason)}")
    end
  end

  defp check_chat_history(%{entity: entity, musicbrainz_id: musicbrainz_id})
       when not is_nil(entity) and not is_nil(musicbrainz_id) do
    Chats.has_any_chats?(entity, musicbrainz_id)
  end

  defp check_chat_history(_assigns), do: false

  defp message_classes("user") do
    "ml-auto bg-red-500 dark:bg-red-700 text-white"
  end

  defp message_classes("assistant") do
    "bg-zinc-100 dark:bg-zinc-700 text-zinc-900 dark:text-zinc-100"
  end

  defp message_classes(_), do: ""
end
