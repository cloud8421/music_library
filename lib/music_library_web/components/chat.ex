defmodule MusicLibraryWeb.Components.Chat do
  use MusicLibraryWeb, :live_component

  require Logger

  alias MusicLibraryWeb.Markdown

  def open(id), do: Fluxon.open_dialog(id)

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:messages, [])
     |> assign(:current_response, "")
     |> assign(:loading, false)
     |> assign(:error, nil)}
  end

  @impl true
  def update(%{chunk: chunk}, socket) do
    {:ok, update(socket, :current_response, &(&1 <> chunk))}
  end

  def update(%{done: true}, socket) do
    completed_message = %{role: "assistant", content: socket.assigns.current_response}

    {:ok,
     socket
     |> update(:messages, &(&1 ++ [completed_message]))
     |> assign(:current_response, "")
     |> assign(:loading, false)}
  end

  def update(%{error: error}, socket) do
    {:ok,
     socket
     |> assign(:error, error)
     |> assign(:loading, false)}
  end

  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.sheet
        id={@sheet_id}
        placement="right"
        class="w-md sm:min-w-lg lg:min-w-2xl flex flex-col h-full"
      >
        <div class="flex items-center gap-2 pb-4 border-b border-zinc-200 dark:border-zinc-700">
          <h2 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
            {gettext("Chat about %{title}", title: @title)}
          </h2>
          <.button
            :if={@messages != []}
            size="icon-sm"
            variant="ghost"
            phx-click="clear_chat"
            phx-target={@myself}
            aria-label={gettext("Clear chat")}
          >
            <.icon name="hero-trash" class="icon" />
          </.button>
        </div>

        <div
          id={"#{@id}-messages"}
          class="flex-1 overflow-y-auto py-4 space-y-4"
          phx-hook=".ScrollBottom"
        >
          <div
            :if={@messages == [] and @current_response == ""}
            class="flex flex-col items-center justify-center h-full text-center text-zinc-500 dark:text-zinc-400"
          >
            <.icon
              name="hero-chat-bubble-left-right"
              class="size-12 mb-4 text-zinc-300 dark:text-zinc-600"
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
            <div :if={message.role == "assistant"} class="prose prose-sm dark:prose-invert">
              {raw(Markdown.to_html(message.content))}
            </div>
          </div>

          <div
            :if={@current_response != ""}
            class="max-w-[85%] rounded-lg px-4 py-2 text-sm bg-zinc-100 dark:bg-zinc-700 text-zinc-900 dark:text-zinc-100"
          >
            <div class="prose prose-sm dark:prose-invert">
              {raw(Markdown.to_html(@current_response))}
            </div>
          </div>

          <div
            :if={@loading and @current_response == ""}
            class="flex items-center gap-2 text-zinc-500 dark:text-zinc-400"
          >
            <.loading class="size-4" />
            <span class="text-sm">{gettext("Thinking...")}</span>
          </div>

          <div
            :if={@error}
            class="max-w-[85%] rounded-lg px-4 py-2 text-sm bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-300"
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

        <div class="pt-4 border-t border-zinc-200 dark:border-zinc-700">
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

  @impl true
  def handle_event("send_message", %{"message" => ""}, socket), do: {:noreply, socket}

  def handle_event("send_message", %{"message" => text}, socket),
    do: do_send_message(socket, text)

  def handle_event("clear_chat", _params, socket) do
    {:noreply,
     socket
     |> assign(:messages, [])
     |> assign(:current_response, "")
     |> assign(:error, nil)}
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
     |> assign(:loading, true)
     |> assign(:current_response, "")
     |> assign(:error, nil)}
  end

  defp message_classes("user") do
    "ml-auto bg-blue-500 dark:bg-blue-600 text-white"
  end

  defp message_classes("assistant") do
    "bg-zinc-100 dark:bg-zinc-700 text-zinc-900 dark:text-zinc-100"
  end

  defp message_classes(_), do: ""
end
