defmodule MusicLibraryWeb.WishlistLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.Components.Pagination
  import MusicLibraryWeb.LiveHelpers.Params
  import MusicLibraryWeb.RecordComponents

  alias MusicLibrary.Records
  alias MusicLibrary.Wishlist
  alias MusicLibraryWeb.ErrorMessages

  @default_records_list_params %{
    query: "",
    page: 1,
    page_size: 72,
    order: :alphabetical
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
      <header class="mb-2">
        <div class="my-2 flex items-center justify-between gap-6">
          <.search_form query={@record_list_params.query} />
          <.button
            variant="solid"
            size="sm"
            patch={~p"/wishlist/import"}
          >
            <.icon name="hero-plus" class="icon" aria-hidden="true" data-slot="icon" />
            <span class="sr-only sm:not-sr-only">{gettext("Add")}</span>
          </.button>
        </div>
      </header>

      <div class="mt-6 flex items-end justify-between gap-6">
        <.button_group>
          <.button
            patch={order_path(@record_list_params, :insertion)}
            size="sm"
            class={[
              @record_list_params.order == :insertion && "bg-zinc-100! dark:bg-zinc-700!"
            ]}
          >
            <.icon name="hero-star" class="icon" aria-hidden="true" data-slot="icon" />
            <span class="sr-only sm:not-sr-only">{gettext("Insertion")}</span>
          </.button>
          <.button
            patch={order_path(@record_list_params, :alphabetical)}
            size="sm"
            class={[
              @record_list_params.order == :alphabetical && "bg-zinc-100 dark:bg-zinc-700!"
            ]}
          >
            <.icon name="hero-user-solid" class="icon" aria-hidden="true" data-slot="icon" />
            <span class="sr-only sm:not-sr-only">{gettext("A->Z")}</span>
          </.button>
          <.button
            patch={order_path(@record_list_params, :release)}
            size="sm"
            class={[
              @record_list_params.order == :release && "bg-zinc-100! dark:bg-zinc-700!"
            ]}
          >
            <.icon name="hero-calendar-days" class="icon" aria-hidden="true" data-slot="icon" />
            <span class="sr-only sm:not-sr-only">{gettext("Release")}</span>
          </.button>
        </.button_group>

        <.button_group>
          <.button
            phx-click="set_display"
            phx-value-mode="grid"
            size="sm"
            class={[
              @display == :grid && "bg-zinc-100! dark:bg-zinc-700!"
            ]}
          >
            <.icon
              name="hero-squares-2x2"
              class="icon"
              aria-hidden="true"
              data-slot="icon"
            />
            <span class="sr-only sm:not-sr-only">
              {gettext("Grid")}
            </span>
          </.button>
          <.button
            phx-click="set_display"
            phx-value-mode="list"
            size="sm"
            class={[
              @display == :list && "bg-zinc-100! dark:bg-zinc-700!"
            ]}
          >
            <.icon name="hero-list-bullet" class="icon" aria-hidden="true" data-slot="icon" />
            <span class="sr-only sm:not-sr-only">
              {gettext("List")}
            </span>
          </.button>
        </.button_group>
      </div>

      <.record_grid
        :if={@display == :grid}
        id="wishlist"
        records={@streams.records}
        record_show_path={fn record -> ~p"/wishlist/#{record}" end}
        record_edit_path={fn record -> ~p"/wishlist/#{record}/edit" end}
        display_artist_names
        density={:high}
      />

      <.record_list
        :if={@display == :list}
        current_date={@current_date}
        records={@streams.records}
        record_show_path={fn record -> ~p"/wishlist/#{record}" end}
        record_edit_path={fn record -> ~p"/wishlist/#{record}/edit" end}
      />

      <.structured_modal
        :if={@live_action == :edit}
        id="record-modal"
        on_close={JS.patch(back_path(@record_list_params))}
      >
        <.live_component
          module={MusicLibraryWeb.Components.RecordForm}
          id={@record.id}
          action={@live_action}
          show_purchased_at={false}
          record={@record}
          patch={back_path(@record_list_params)}
        />
      </.structured_modal>

      <.structured_modal
        :if={@live_action == :import}
        id="record-modal"
        on_close={JS.patch(back_path(@record_list_params))}
      >
        <.live_component
          module={MusicLibraryWeb.Components.AddRecord}
          id={:search}
          title={@page_title}
          action={@live_action}
          record={@record}
          patch={back_path(@record_list_params)}
          initial_query={@import_query}
          icon_name="hero-plus"
        />
      </.structured_modal>

      <.pagination id={:bottom_pagination} pagination_params={@record_list_params} />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_date = Date.utc_today()

    {:ok,
     socket
     |> assign(current_section: :wishlist)
     |> assign(:import_query, "")
     |> assign(:display, :grid)
     |> assign(:current_date, current_date)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :import, params) do
    import_query = params["import_query"] || ""

    socket
    |> apply_fallback_index(params, :records, &apply_action/3)
    |> assign(:page_title, gettext("Add new Record · Wishlist"))
    |> assign(:import_query, import_query)
    |> assign(:record, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id} = params) do
    record = Records.get_record!(id)

    socket
    |> apply_fallback_index(params, :records, &apply_action/3)
    |> assign(:page_title, page_title(:edit, record))
    |> assign(:record, record)
  end

  defp apply_action(socket, :index, params) do
    query = params["query"] || ""
    order = parse_order(params["order"] || "insertion", [:insertion, :alphabetical, :release])
    total_records = Wishlist.search_records_count(query)

    record_list_params =
      @default_records_list_params
      |> merge_query(query)
      |> merge_order(order)
      |> merge_pagination(params, total_records)

    load_and_assign_records(socket, record_list_params)
  end

  @impl true
  def handle_info({MusicLibraryWeb.Components.RecordForm, {:saved, _record}}, socket) do
    {:noreply, load_and_assign_records(socket, socket.assigns.record_list_params)}
  end

  @impl true

  def handle_event("delete", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    {:ok, _} = Records.delete_record(record)

    {:noreply, stream_delete(socket, :records, record)}
  end

  def handle_event("search", %{"query" => query}, socket) do
    qs =
      @default_records_list_params
      |> Map.put(:query, query)
      |> Map.take([:query, :page, :page_size])

    {:noreply, push_patch(socket, to: ~p"/wishlist?#{qs}")}
  end

  def handle_event("import", %{"id" => musicbrainz_id, "format" => format}, socket) do
    case Records.import_from_musicbrainz_release_group(musicbrainz_id,
           format: format,
           purchased_at: nil
         ) do
      {:ok, record} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Record wishlisted successfully"))
         |> push_navigate(to: ~p"/wishlist/#{record.id}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error wishlisting record") <> ": " <> ErrorMessages.friendly_message(reason)
         )
         |> push_patch(to: ~p"/wishlist")}
    end
  end

  def handle_event("add-to-collection", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    current_time = DateTime.utc_now()

    case Records.update_record(record, %{"purchased_at" => current_time}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Record added to the collection"))
         |> push_patch(to: ~p"/wishlist")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  def handle_event("set_display", %{"mode" => mode}, socket) do
    mode = parse_mode(mode)

    {:noreply,
     socket
     |> assign(:display, mode)
     |> load_and_assign_records(socket.assigns.record_list_params)}
  end

  defp load_and_assign_records(socket, record_list_params) do
    offset = page_to_offset(record_list_params.page, record_list_params.page_size)

    records =
      Wishlist.search_records(record_list_params.query,
        limit: record_list_params.page_size,
        offset: offset,
        order: record_list_params.order
      )

    socket
    |> assign(:page_title, gettext("Wishlist"))
    |> assign(:record, nil)
    |> assign(:record_list_params, record_list_params)
    |> stream(:records, records, reset: true)
  end

  defp order_path(record_list_params, order) do
    qs =
      record_list_params
      |> Map.take([:query])
      |> Map.put(:order, order)
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/wishlist?#{qs}"
  end

  defp back_path(record_list_params) do
    qs =
      record_list_params
      |> Map.take([:query, :page, :page_size])
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/wishlist?#{qs}"
  end

  defp page_title(action, record) do
    Enum.join(
      [
        Records.Record.artist_names(record),
        "-",
        record.title,
        "·",
        title_segment(action),
        "·",
        gettext("Wishlist")
      ],
      " "
    )
  end

  defp title_segment(:edit), do: gettext("Edit")
end
