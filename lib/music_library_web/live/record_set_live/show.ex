defmodule MusicLibraryWeb.RecordSetLive.Show do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.RecordComponents, only: [artist_links: 1, type_label: 1, format_label: 1]

  alias MusicLibrary.{Records, RecordSets}
  alias MusicLibrary.RecordSets.RecordSet
  alias MusicLibraryWeb.Markdown
  alias Phoenix.LiveView.JS

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <div class="mt-4">
        <header class="mt-4 flex items-baseline justify-between">
          <div>
            <h1 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
              {@record_set.name}
            </h1>
            <span class="text-xs text-zinc-500 dark:text-zinc-400">
              {gettext("%{collected}/%{total} records", RecordSet.count_by_status(@record_set))}
            </span>
          </div>
          <div class="flex items-center gap-2">
            <.dropdown id="set-actions" placement="bottom-end">
              <:toggle>
                <.button variant="soft">
                  <span class="sr-only">{gettext("Actions")}</span>
                  <.icon
                    name="hero-ellipsis-vertical"
                    class="icon text-zinc-500 dark:text-zinc-400 cursor-pointer"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                </.button>
              </:toggle>
              <.dropdown_link
                id="set-actions-edit"
                patch={~p"/record-sets/#{@record_set}/show/edit"}
              >
                {gettext("Edit")}
              </.dropdown_link>
              <.dropdown_separator />
              <.dropdown_button
                phx-click="delete_set"
                data-confirm={gettext("Are you sure?")}
                class={[
                  "text-red-900! hover:bg-red-50! dark:text-red-500! dark:hover:bg-red-900/30! dark:hover:text-red-600!"
                ]}
              >
                {gettext("Delete")}
              </.dropdown_button>
            </.dropdown>
          </div>
        </header>

        <article
          :if={@record_set.description}
          class="mt-4 prose dark:prose-invert prose-zinc prose-sm prose-h1:text-sm max-w-none"
        >
          {render_description(@record_set.description)}
        </article>

        <div class="mt-6">
          <div
            class="grid grid-cols-3 sm:grid-cols-6 lg:grid-cols-8 gap-4"
            id="record-set-records"
            phx-hook="SortableList"
          >
            <div
              :for={item <- @record_set.items}
              id={"record-item-#{item.id}"}
              data-sortable-item
              data-record-id={item.record.id}
              class={[
                "group relative",
                is_nil(item.record.purchased_at) &&
                  "opacity-60 dark:opacity-40 hover:opacity-100 transition-opacity"
              ]}
            >
              <.link
                :if={item.record.purchased_at}
                navigate={~p"/collection/#{item.record}"}
              >
                <MusicLibraryWeb.RecordComponents.record_cover
                  record={item.record}
                  class="rounded-lg aspect-square object-cover"
                  width={468}
                />
              </.link>
              <.link
                :if={!item.record.purchased_at}
                navigate={~p"/wishlist/#{item.record}"}
              >
                <MusicLibraryWeb.RecordComponents.record_cover
                  record={item.record}
                  class="rounded-lg aspect-square object-cover"
                  width={468}
                />
              </.link>
              <button
                data-sortable-handle
                class="absolute top-1 left-1 flex items-center justify-center rounded-full bg-zinc-100/50 hover:bg-zinc-100/75 dark:bg-zinc-700/50 dark:hover:bg-zinc-700/75 size-8 sm:size-6 cursor-grab active:cursor-grabbing"
              >
                <.icon
                  name="hero-bars-2"
                  class="size-3.5 text-zinc-800 dark:text-zinc-200"
                  aria-hidden="true"
                />
              </button>
              <button
                phx-click="remove_record"
                phx-value-record-id={item.record.id}
                data-confirm={gettext("Remove this record from the set?")}
                class="absolute top-1 right-1 flex items-center justify-center rounded-full bg-zinc-100/50 hover:bg-red-100/75 dark:bg-zinc-700/50 dark:hover:bg-red-900/50 size-8 sm:size-6 cursor-pointer"
              >
                <span class="sr-only">{gettext("Remove")}</span>
                <.icon
                  name="hero-trash"
                  class="size-3.5 text-zinc-800 hover:text-red-700 dark:text-zinc-200 dark:hover:text-red-400"
                  aria-hidden="true"
                />
              </button>
              <h2 class="mt-1 text-sm leading-6 text-zinc-700">
                <.artist_links joinphrase_class="text-sm" artists={item.record.artists} />
              </h2>
              <h3 class="flex font-semibold text-sm leading-5 text-zinc-700 dark:text-zinc-300 text-wrap">
                {item.record.title}
              </h3>
              <p class="pointer-events-none block text-sm font-medium text-zinc-500">
                {format_label(item.record.format)} · {type_label(item.record.type)}
              </p>
              <p class="pointer-events-none block text-sm font-medium text-zinc-500">
                <.icon
                  name="hero-calendar-days"
                  class="-mt-1 h-4 w-4"
                  aria-hidden="true"
                  data-slot="icon"
                />
                {Records.Record.format_release_date(item.record.release_date)}
              </p>
            </div>
            <.link
              patch={~p"/record-sets/#{@record_set}/show/add-record"}
              class={[
                "aspect-square",
                "border-2 border-dashed border-zinc-300 dark:border-zinc-600",
                "rounded-lg flex items-center justify-center",
                "hover:border-zinc-400 dark:hover:border-zinc-500",
                "hover:bg-zinc-50 dark:hover:bg-zinc-800",
                "transition-colors cursor-pointer"
              ]}
            >
              <.icon
                name="hero-plus"
                class="h-8 w-8 text-zinc-400 dark:text-zinc-500"
                aria-hidden="true"
                data-slot="icon"
              />
            </.link>
          </div>
        </div>
      </div>

      <.structured_modal
        :if={@live_action == :edit}
        id="record-set-modal"
        on_close={JS.patch(~p"/record-sets/#{@record_set}")}
      >
        <.live_component
          module={MusicLibraryWeb.RecordSetLive.Form}
          id={@record_set.id}
          title={@page_title}
          action={@live_action}
          record_set={@record_set}
          patch={~p"/record-sets/#{@record_set}"}
        />
      </.structured_modal>

      <.structured_modal
        :if={@live_action == :add_record}
        id="record-picker-modal"
        on_close={JS.patch(~p"/record-sets/#{@record_set}")}
      >
        <.live_component
          module={MusicLibraryWeb.RecordSetLive.RecordPicker}
          id={"record-picker-#{@record_set.id}"}
          title={@page_title}
          record_set={@record_set}
          patch={~p"/record-sets/#{@record_set}"}
        />
      </.structured_modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :current_section, :record_sets)}
  end

  @impl true
  def handle_params(%{"id" => id}, _url, socket) do
    record_set = RecordSets.get_record_set!(id)

    {:noreply,
     socket
     |> assign(:record_set, record_set)
     |> assign(:page_title, page_title(socket.assigns.live_action, record_set))}
  end

  @impl true
  def handle_info(
        {MusicLibraryWeb.RecordSetLive.Form, {:updated, record_set}},
        socket
      ) do
    {:noreply,
     socket
     |> assign(:record_set, record_set)
     |> assign(:page_title, page_title(socket.assigns.live_action, record_set))}
  end

  def handle_info(
        {MusicLibraryWeb.RecordSetLive.RecordPicker, {:added, record_set}},
        socket
      ) do
    {:noreply, assign(socket, :record_set, record_set)}
  end

  @impl true
  def handle_event("delete_set", _params, socket) do
    case RecordSets.delete_record_set(socket.assigns.record_set) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Set deleted successfully"))
         |> push_navigate(to: ~p"/record-sets")}

      {:error, _changeset} ->
        {:noreply, put_toast(socket, :error, gettext("Failed to delete set"))}
    end
  end

  def handle_event("remove_record", %{"record-id" => record_id}, socket) do
    {:ok, updated_set} =
      RecordSets.remove_record_from_set(socket.assigns.record_set, record_id)

    {:noreply, assign(socket, :record_set, updated_set)}
  end

  def handle_event("reorder", %{"record_ids" => record_ids}, socket) do
    {:ok, updated_set} =
      RecordSets.reorder_records_in_set(socket.assigns.record_set, record_ids)

    {:noreply, assign(socket, :record_set, updated_set)}
  end

  defp page_title(:show, record_set), do: record_set.name
  defp page_title(:edit, record_set), do: gettext("Edit") <> " · " <> record_set.name
  defp page_title(:add_record, record_set), do: gettext("Add Record") <> " · " <> record_set.name

  # sobelow_skip ["XSS.Raw"]
  # Markdown.to_html/1 sanitizes HTML via MDEx (ammonia)
  defp render_description(description) do
    description
    |> Markdown.to_html()
    |> raw()
  end
end
