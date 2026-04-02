defmodule MusicLibraryWeb.RecordSetLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.Components.Pagination
  import MusicLibraryWeb.LiveHelpers.Params

  import MusicLibraryWeb.RecordComponents,
    only: [artist_links: 1, type_label: 1, format_label: 1, release_status_tooltip: 1]

  alias MusicLibrary.{Records, RecordSets}
  alias MusicLibrary.RecordSets.RecordSet
  alias MusicLibraryWeb.Markdown

  @default_list_params %{
    page: 1,
    page_size: 20,
    query: "",
    order: :updated_at
  }

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_section={@current_section}
      socket={@socket}
      toasts_sync={assigns[:toasts_sync]}
    >
      <header class="mb-6">
        <div class="my-2 flex items-center justify-between gap-6">
          <.search_form query={@list_params.query} />
          <.button
            variant="solid"
            size="sm"
            patch={~p"/record-sets/new"}
          >
            <.icon name="hero-plus" class="icon" aria-hidden="true" data-slot="icon" />
            {gettext("New Set")}
          </.button>
        </div>
      </header>

      <div class="mt-4 flex items-end justify-between gap-6">
        <.button_group>
          <.button
            patch={order_path(@list_params, :updated_at)}
            size="sm"
            class={[@list_params.order == :updated_at && "bg-zinc-100! dark:bg-zinc-700!"]}
          >
            <.icon name="hero-clock" class="icon" aria-hidden="true" data-slot="icon" />
            <span class="sr-only sm:not-sr-only">{gettext("Updated")}</span>
          </.button>
          <.button
            patch={order_path(@list_params, :alphabetical)}
            size="sm"
            class={[@list_params.order == :alphabetical && "bg-zinc-100! dark:bg-zinc-700!"]}
          >
            <.icon name="hero-user-solid" class="icon" aria-hidden="true" data-slot="icon" />
            <span class="sr-only sm:not-sr-only">{gettext("A->Z")}</span>
          </.button>
        </.button_group>
      </div>

      <div class="mt-6 space-y-6">
        <ul id="record-sets-list" class="space-y-6" phx-update="stream">
          <li
            id="no-record-sets"
            class="hidden rounded-lg bg-zinc-50 p-8 text-center only:block dark:bg-zinc-800"
          >
            <.icon name="hero-rectangle-stack" class="mx-auto mb-4 size-12 text-zinc-400" />
            <p class="text-zinc-600 dark:text-zinc-400">
              {gettext("No record sets yet")}
            </p>
          </li>

          <.record_set_card
            :for={{id, record_set} <- @streams.record_sets}
            id={id}
            record_set={record_set}
            list_params={@list_params}
          />
        </ul>

        <.pagination id={:bottom_pagination} pagination_params={@list_params} />
      </div>

      <.structured_modal
        :if={@live_action in [:new, :edit]}
        id="record-set-modal"
        on_close={JS.patch(back_path(@list_params))}
      >
        <.live_component
          module={MusicLibraryWeb.RecordSetLive.Form}
          id={@record_set.id || :new}
          title={@page_title}
          action={@live_action}
          record_set={@record_set}
          patch={back_path(@list_params)}
        />
      </.structured_modal>

      <.structured_modal
        :if={@live_action == :add_record}
        id="record-picker-modal"
        on_close={JS.patch(back_path(@list_params))}
      >
        <.live_component
          module={MusicLibraryWeb.RecordSetLive.RecordPicker}
          id={"record-picker-#{@record_set.id}"}
          title={@page_title}
          record_set={@record_set}
          patch={back_path(@list_params)}
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
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"id" => id} = params) do
    socket
    |> apply_fallback_index(params, :record_sets, &apply_action/3)
    |> assign(:page_title, gettext("Edit Set"))
    |> assign(:record_set, RecordSets.get_record_set!(id))
  end

  defp apply_action(socket, :new, params) do
    socket
    |> apply_fallback_index(params, :record_sets, &apply_action/3)
    |> assign(:page_title, gettext("New Set"))
    |> assign(:record_set, %RecordSet{})
  end

  defp apply_action(socket, :add_record, %{"id" => id} = params) do
    socket
    |> apply_fallback_index(params, :record_sets, &apply_action/3)
    |> assign(:page_title, gettext("Add Record"))
    |> assign(:record_set, RecordSets.get_record_set!(id))
  end

  defp apply_action(socket, :index, params) do
    query = params["query"] || ""
    order = parse_order(params["order"] || "updated_at")
    total_sets = RecordSets.count_record_sets(query)

    list_params =
      @default_list_params
      |> merge_query(query)
      |> merge_order(order)
      |> merge_pagination(params, total_sets)

    load_and_assign_sets(socket, list_params)
  end

  defp load_and_assign_sets(socket, list_params) do
    offset = page_to_offset(list_params.page, list_params.page_size)

    sets =
      RecordSets.search_record_sets(list_params.query,
        offset: offset,
        limit: list_params.page_size,
        order: list_params.order
      )

    socket
    |> assign(:list_params, list_params)
    |> assign(:page_title, gettext("Record Sets"))
    |> assign(:record_set, nil)
    |> stream(:record_sets, sets, reset: true)
  end

  def back_path(list_params) do
    qs =
      list_params
      |> Map.take([:query, :page, :page_size, :order])
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/record-sets?#{qs}"
  end

  @impl true
  def handle_info(
        {MusicLibraryWeb.RecordSetLive.Form, {:created, _record_set}},
        socket
      ) do
    {:noreply, load_and_assign_sets(socket, socket.assigns.list_params)}
  end

  def handle_info(
        {MusicLibraryWeb.RecordSetLive.Form, {:updated, record_set}},
        socket
      ) do
    {:noreply, update_record_set_in_list(socket, record_set)}
  end

  def handle_info(
        {MusicLibraryWeb.RecordSetLive.RecordPicker, {:added, record_set}},
        socket
      ) do
    {:noreply, update_record_set_in_list(socket, record_set)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    qs =
      @default_list_params
      |> Map.put(:query, query)
      |> Map.put(:order, socket.assigns.list_params.order)
      |> Map.take([:query, :page, :page_size, :order])

    {:noreply, push_patch(socket, to: ~p"/record-sets?#{qs}")}
  end

  def handle_event("delete_set", %{"id" => id}, socket) do
    record_set = RecordSets.get_record_set!(id)
    {:ok, _} = RecordSets.delete_record_set(record_set)

    {:noreply, load_and_assign_sets(socket, socket.assigns.list_params)}
  end

  def handle_event("remove_record", %{"set-id" => set_id, "record-id" => record_id}, socket) do
    record_set = RecordSets.get_record_set!(set_id)
    {:ok, updated_set} = RecordSets.remove_record_from_set(record_set, record_id)

    {:noreply, update_record_set_in_list(socket, updated_set)}
  end

  def handle_event("reorder", %{"set_id" => set_id, "record_ids" => record_ids}, socket) do
    record_set = RecordSets.get_record_set!(set_id)
    {:ok, updated_set} = RecordSets.reorder_records_in_set(record_set, record_ids)

    {:noreply, update_record_set_in_list(socket, updated_set)}
  end

  defp update_record_set_in_list(socket, updated_set) do
    stream_insert(socket, :record_sets, updated_set)
  end

  defp parse_order("alphabetical"), do: :alphabetical
  defp parse_order("updated_at"), do: :updated_at
  defp parse_order(_), do: :updated_at

  defp order_path(list_params, order) do
    qs =
      list_params
      |> Map.take([:query])
      |> Map.put(:order, order)
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/record-sets?#{qs}"
  end

  attr :id, :string, required: true
  attr :record_set, RecordSet, required: true
  attr :list_params, :map, required: true

  defp record_set_card(assigns) do
    assigns =
      assigns
      |> assign(:html_description, render_description(assigns.record_set.description))
      |> assign(
        :patch_params,
        assigns.list_params
        |> Map.take([:query, :page, :page_size, :order])
        |> Enum.filter(fn {_, v} -> v not in ["", nil] end)
      )

    ~H"""
    <li
      id={@id}
      class="rounded-md border-zinc-200 bg-white p-4 shadow-sm dark:border-zinc-700 dark:bg-zinc-900"
    >
      <div class="mb-3 flex items-baseline justify-between">
        <div class="grow">
          <header class="sm:flex sm:items-baseline sm:justify-start">
            <h2 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
              <.link navigate={~p"/record-sets/#{@record_set}"} class="hover:underline">
                {@record_set.name}
              </.link>
            </h2>
            <span class="text-xs text-zinc-500 sm:ml-2 dark:text-zinc-400">
              {gettext("%{collected}/%{total} records", RecordSet.count_by_status(@record_set))}
            </span>
          </header>
          <article
            :if={@record_set.description}
            class="dark:prose-invert prose prose-h1:text-sm prose-sm prose-zinc my-4 max-w-none text-sm"
          >
            {@html_description}
          </article>
        </div>
        <div class="flex items-center gap-2">
          <.dropdown id={"set-actions-#{@record_set.id}"} placement="bottom-end">
            <:toggle>
              <.button variant="soft">
                <span class="sr-only">{gettext("Actions")}</span>
                <.icon
                  name="hero-ellipsis-vertical"
                  class="size-5 cursor-pointer text-zinc-500 dark:text-zinc-400"
                  aria-hidden="true"
                  data-slot="icon"
                />
              </.button>
            </:toggle>
            <.dropdown_link
              id={"set-actions-#{@record_set.id}-edit"}
              patch={~p"/record-sets/#{@record_set}/edit?#{@patch_params}"}
            >
              {gettext("Edit")}
            </.dropdown_link>
            <.dropdown_separator />
            <.dropdown_button
              phx-click="delete_set"
              phx-value-id={@record_set.id}
              data-confirm={gettext("Are you sure?")}
              class={[
                "text-red-900! hover:bg-red-50! dark:text-red-500! dark:hover:bg-red-900/30! dark:hover:text-red-600!"
              ]}
            >
              {gettext("Delete")}
            </.dropdown_button>
          </.dropdown>
        </div>
      </div>

      <div
        class="grid grid-cols-3 gap-3 pb-2 md:grid-cols-6 lg:grid-cols-8 xl:grid-cols-12"
        id={"record-set-#{@record_set.id}-items"}
        phx-hook="SortableList"
        data-set-id={@record_set.id}
      >
        <div
          :for={item <- @record_set.items}
          :key={item.id}
          data-sortable-item
          data-record-id={item.record.id}
          class={[
            "group relative flex-none",
            is_nil(item.record.purchased_at) &&
              "opacity-60 transition-opacity hover:opacity-100 dark:opacity-40"
          ]}
        >
          <.link
            :if={item.record.purchased_at}
            navigate={~p"/collection/#{item.record}"}
          >
            <MusicLibraryWeb.RecordComponents.record_cover
              record={item.record}
              class="aspect-square rounded-lg object-cover"
              width={256}
            />
          </.link>
          <.link
            :if={!item.record.purchased_at}
            navigate={~p"/wishlist/#{item.record}"}
          >
            <MusicLibraryWeb.RecordComponents.record_cover
              record={item.record}
              class="aspect-square rounded-lg object-cover"
              width={256}
            />
          </.link>
          <div
            data-sortable-handle
            class="absolute top-1 left-1 flex size-8 cursor-grab items-center justify-center rounded-full bg-zinc-100/50 hover:bg-zinc-100/75 active:cursor-grabbing sm:size-5 dark:bg-zinc-700/50 dark:hover:bg-zinc-700/75"
          >
            <.icon
              name="hero-bars-2"
              class="size-3.5 text-zinc-800 dark:text-zinc-200"
              aria-hidden="true"
            />
          </div>
          <button
            phx-click="remove_record"
            phx-value-set-id={@record_set.id}
            phx-value-record-id={item.record.id}
            data-confirm={gettext("Remove this record from the set?")}
            class="absolute top-1 right-1 flex size-8 cursor-pointer items-center justify-center rounded-full bg-zinc-100/50 hover:bg-red-100/75 sm:size-5 dark:bg-zinc-700/50 dark:hover:bg-red-900/50"
          >
            <span class="sr-only">{gettext("Remove")}</span>
            <.icon
              name="hero-trash"
              class="size-3.5 text-zinc-800 hover:text-red-700 dark:text-zinc-200 dark:hover:text-red-400"
              aria-hidden="true"
            />
          </button>
          <h2 class="mt-1 text-sm/6 text-zinc-700">
            <.artist_links joinphrase_class="text-sm" artists={item.record.artists} />
          </h2>
          <h3 class="flex items-center gap-1 text-sm/5 font-semibold text-wrap text-zinc-700 dark:text-zinc-300">
            {item.record.title}
            <.release_status_tooltip record={item.record} />
          </h3>
          <p class="pointer-events-none block text-sm font-medium text-zinc-500">
            {format_label(item.record.format)} · {type_label(item.record.type)}
          </p>
          <p class="pointer-events-none block text-sm font-medium text-zinc-500">
            <.icon
              name="hero-calendar-days"
              class="-mt-1 size-4"
              aria-hidden="true"
              data-slot="icon"
            />
            {Records.Record.format_release_date(item.record.release_date)}
          </p>
        </div>

        <.link
          patch={~p"/record-sets/#{@record_set}/add-record"}
          class={[
            "aspect-square flex-none",
            "border-2 border-dashed border-zinc-300 dark:border-zinc-600",
            "flex items-center justify-center rounded-lg",
            "hover:border-zinc-400 dark:hover:border-zinc-500",
            "hover:bg-zinc-100 dark:hover:bg-zinc-800",
            "cursor-pointer transition-colors"
          ]}
        >
          <.icon
            name="hero-plus"
            class="size-8 text-zinc-400 dark:text-zinc-500"
            aria-hidden="true"
            data-slot="icon"
          />
        </.link>
      </div>
    </li>
    """
  end

  # sobelow_skip ["XSS.Raw"]
  # Markdown.to_html/1 sanitizes HTML via MDEx (ammonia)
  defp render_description(description) do
    description
    |> Markdown.to_html()
    |> raw()
  end
end
