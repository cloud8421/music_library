defmodule MusicLibraryWeb.Components.Chat do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Chats
  alias MusicLibraryWeb.Markdown

  def open(id), do: Fluxon.open_dialog(id)

  @impl true
  def mount(socket) do
    {:ok, reset_chat_state(socket)}
  end

  @impl true
  def update(%{event: %{status: :streaming, chat: chat}}, socket) do
    doc = Markdown.new_streaming_doc(link_target: "_blank")

    {:ok,
     socket
     |> assign(:chat, chat)
     |> assign(:loading, true)
     |> assign(:streaming_doc, doc)}
  end

  def update(%{event: %{status: :chunk_received, chunk: chunk}}, socket) do
    doc = MDEx.Document.put_markdown(socket.assigns.streaming_doc, chunk)

    {:ok,
     socket
     |> assign(:loading, false)
     |> assign(:streaming_doc, doc)}
  end

  def update(%{event: %{status: :idle, chat: chat}}, socket) do
    send(self(), {__MODULE__, :chats_changed})

    {:ok,
     socket
     |> assign(:streaming_doc, nil)
     |> assign(:chat, chat)}
  end

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    if changed?(socket, :entity) or changed?(socket, :musicbrainz_id) do
      {:ok, load_for_entity(socket)}
    else
      {:ok, socket}
    end
  end

  @impl true
  def render(assigns) do
    messages = if assigns.chat, do: assigns.chat.messages, else: []
    assigns = assign(assigns, :messages, messages)

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
        :if={@messages == []}
        class="flex h-full flex-col items-center justify-center text-center text-zinc-500 dark:text-zinc-400"
      >
        <.icon
          name="hero-chat-bubble-left-right"
          class="mb-4 size-12 text-zinc-300 dark:text-zinc-600"
        />
        <p class="text-sm font-medium">{@empty_prompt}</p>
      </div>

      <div
        :for={{message, index} <- Enum.with_index(@messages)}
        class={[
          "max-w-[85%] rounded-lg px-4 py-2 text-sm",
          message_classes(message.role)
        ]}
      >
        <p :if={message.role == "user"} class="whitespace-pre-wrap">{message.content}</p>
        <div
          :if={message.role == "assistant"}
          id={"#{@id}-msg-#{index}"}
          class="dark:prose-invert prose prose-sm"
        >
          {raw(Markdown.to_html(message.content, link_target: "_blank"))}
        </div>
        <div :if={message.role == "assistant"} class="-mr-2 -mb-1 flex justify-end">
          <.copy_to_clipboard
            target_id={"#{@id}-msg-#{index}"}
            label={gettext("Copy message")}
          />
        </div>
      </div>

      <div
        :if={@streaming_doc != nil && !@loading}
        class="max-w-[85%] rounded-lg bg-zinc-100 px-4 py-2 text-sm text-zinc-900 dark:bg-zinc-700 dark:text-zinc-100"
      >
        <div class="dark:prose-invert prose prose-sm">
          {raw(Markdown.streaming_to_html(@streaming_doc, link_target: "_blank"))}
        </div>
      </div>

      <div
        :if={@loading}
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
    {:noreply, do_new_chat(socket)}
  end

  def handle_event("show_chat_list", _params, socket) do
    chats = Chats.list_chats(socket.assigns.entity, socket.assigns.musicbrainz_id)

    {:noreply,
     socket
     |> assign(:chats, chats)
     |> assign(:view, :list)}
  end

  def handle_event("select_chat", %{"id" => chat_id}, socket) do
    chat_module = socket.assigns.chat_module

    {record, embedding_text} = socket.assigns.chat_context
    instructions = chat_module.build_instructions(record, embedding_text)

    params = %{
      chat_id: chat_id,
      instructions: instructions
    }

    :ok = Chats.ensure_session(params)
    :ok = Chats.subscribe(chat_id)
    chat = Chats.Session.get_history(chat_id)

    {:noreply,
     socket
     |> assign(:chat, chat)
     |> assign(:chat_id, chat.id)
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
    Chats.Session.send_message(socket.assigns.chat_id, String.trim(text))

    {:noreply,
     socket
     |> assign(:has_history, true)
     |> assign(:error, nil)}
  end

  defp reset_chat_state(socket) do
    socket
    |> assign(:streaming_doc, nil)
    |> assign(:loading, false)
    |> assign(:error, nil)
    |> assign(:view, :active)
    |> assign(:chat_id, Ecto.UUID.generate())
    |> assign(:chat, nil)
    |> assign(:chats, [])
    |> assign(:has_history, false)
  end

  defp load_for_entity(socket) do
    socket = reset_chat_state(socket)

    if Chats.has_any_chats?(socket.assigns.entity, socket.assigns.musicbrainz_id) do
      chats = Chats.list_chats(socket.assigns.entity, socket.assigns.musicbrainz_id)

      socket
      |> assign(:has_history, true)
      |> assign(:chats, chats)
      |> assign(:view, :list)
    else
      do_new_chat(socket)
    end
  end

  defp do_new_chat(socket) do
    chat_id = Ecto.UUID.generate()
    chat_module = socket.assigns.chat_module

    {record, embedding_text} = socket.assigns.chat_context
    instructions = chat_module.build_instructions(record, embedding_text)

    params = %{
      chat_id: chat_id,
      instructions: instructions,
      new_chat_params: %{
        entity: socket.assigns.entity,
        musicbrainz_id: socket.assigns.musicbrainz_id
      }
    }

    :ok = Chats.ensure_session(params)
    :ok = Chats.subscribe(chat_id)
    chat = Chats.Session.get_history(chat_id)

    socket
    |> assign(:error, nil)
    |> assign(:chat_id, chat_id)
    |> assign(:chat, chat)
    |> assign(:view, :active)
  end

  defp message_classes("user") do
    "ml-auto bg-red-500 dark:bg-red-700 text-white"
  end

  defp message_classes("assistant") do
    "bg-zinc-100 dark:bg-zinc-700 text-zinc-900 dark:text-zinc-100"
  end

  defp message_classes(_), do: ""
end
