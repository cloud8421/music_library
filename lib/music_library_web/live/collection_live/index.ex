defmodule MusicLibraryWeb.CollectionLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.Components.BarcodeScanner, only: [barcode_icon: 1]
  import MusicLibraryWeb.Components.Pagination
  import MusicLibraryWeb.LiveHelpers.Params
  import MusicLibraryWeb.RecordComponents

  alias MusicLibrary.Collection
  alias MusicLibrary.Records
  alias MusicLibraryWeb.CollectionLive.Show

  @default_records_list_params %{
    query: "",
    page: 1,
    page_size: 72,
    order: :purchase
  }

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <header class="gap-6 mb-2">
        <div class="flex items-center justify-between gap-6 mb-2 mt-2">
          <.search_form query={@record_list_params.query} />
          <.button_group>
            <.button
              variant="solid"
              size="sm"
              patch={~p"/collection/import"}
            >
              <.icon name="hero-plus" class="icon" aria-hidden="true" data-slot="icon" />
              {gettext("Add")}
            </.button>
            <.button
              variant="solid"
              size="sm"
              patch={~p"/collection/scan"}
            >
              <.barcode_icon class="icon fill-current" />
              {gettext("Scan")}
            </.button>
          </.button_group>
        </div>
      </header>

      <div class="flex items-end justify-between gap-6 mt-8">
        <.button_group>
          <.button
            patch={order_path(@record_list_params, :purchase)}
            size="sm"
            class={[
              @record_list_params.order == :purchase && "bg-zinc-100! dark:bg-zinc-700!"
            ]}
          >
            <.icon
              name="hero-banknotes-solid"
              class="icon"
              aria-hidden="true"
              data-slot="icon"
            />
            <span class="sr-only sm:not-sr-only">{gettext("Purchase")}</span>
          </.button>
          <.button
            patch={order_path(@record_list_params, :alphabetical)}
            size="sm"
            class={[
              @record_list_params.order == :alphabetical && "bg-zinc-100! dark:bg-zinc-700!"
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
        id="collection"
        records={@streams.records}
        record_show_path={fn record -> ~p"/collection/#{record}" end}
        record_edit_path={fn record -> ~p"/collection/#{record}/edit" end}
        display_artist_names
        density={:high}
      />

      <.record_list
        :if={@display == :list}
        records={@streams.records}
        record_show_path={fn record -> ~p"/collection/#{record}" end}
        record_edit_path={fn record -> ~p"/collection/#{record}/edit" end}
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
          show_purchased_at={true}
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
          initial_query=""
          icon_name="hero-plus"
        />
      </.structured_modal>

      <.structured_modal
        :if={@live_action == :barcode_scan}
        id="barcode-scanner-modal"
        on_close={JS.patch(back_path(@record_list_params))}
      >
        <.live_component
          module={MusicLibraryWeb.Components.BarcodeScanner}
          id={:barcode_scanner}
          title={@page_title}
          action={@live_action}
          patch={back_path(@record_list_params)}
        />
      </.structured_modal>

      <.pagination id={:bottom_pagination} pagination_params={@record_list_params} />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_section, :collection)
     |> assign(:display, :grid)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :import, params) do
    socket
    |> apply_fallback_index(params)
    |> assign(:page_title, gettext("Add new Record · Collection"))
    |> assign(:record, nil)
  end

  defp apply_action(socket, :barcode_scan, params) do
    socket
    |> apply_fallback_index(params)
    |> assign(:page_title, gettext("Scan barcodes · Collection"))
    |> assign(:record, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id} = params) do
    record = Records.get_record!(id)

    socket
    |> apply_fallback_index(params)
    |> assign(:page_title, Show.page_title(socket.assigns.live_action, record))
    |> assign(:record, record)
  end

  defp apply_action(socket, :index, params) do
    query = params["query"] || ""
    order = parse_order(params["order"] || "purchase")
    total_records = Collection.search_records_count(query)

    record_list_params =
      @default_records_list_params
      |> merge_query(query)
      |> merge_order(order)
      |> merge_pagination(params, total_records)

    load_and_assign_records(socket, record_list_params)
  end

  def apply_fallback_index(socket, params) do
    if get_in(socket.assigns, [:streams, :records]) == nil do
      socket
      |> apply_action(:index, params)
    else
      socket
    end
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

    {:noreply, push_patch(socket, to: ~p"/collection?#{qs}")}
  end

  def handle_event("import", %{"id" => musicbrainz_id, "format" => format}, socket) do
    current_time = DateTime.utc_now()

    case Records.import_from_musicbrainz_release_group(musicbrainz_id,
           format: format,
           purchased_at: current_time
         ) do
      {:ok, record} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Record imported successfully"))
         |> push_navigate(to: ~p"/collection/#{record.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error importing record") <> "," <> inspect(changeset.errors)
         )
         |> push_patch(to: ~p"/collection")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(:error, gettext("Error importing record") <> "," <> inspect(reason))
         |> push_patch(to: ~p"/collection")}
    end
  end

  def handle_event("set_display", %{"mode" => mode}, socket) do
    mode = parse_mode(mode)

    {:noreply,
     socket
     |> assign(:display, mode)
     |> load_and_assign_records(socket.assigns.record_list_params)}
  end

  defp parse_mode("grid"), do: :grid
  defp parse_mode("list"), do: :list

  defp load_and_assign_records(socket, record_list_params) do
    offset = page_to_offset(record_list_params.page, record_list_params.page_size)

    opts = [
      limit: record_list_params.page_size,
      offset: offset,
      order: record_list_params.order
    ]

    records =
      Collection.search_records(record_list_params.query, opts)

    socket
    |> assign(:page_title, gettext("Collection"))
    |> assign(:record, nil)
    |> assign(:record_list_params, record_list_params)
    |> stream(:records, records, reset: true)
  end

  defp parse_order("alphabetical"), do: :alphabetical
  defp parse_order("purchase"), do: :purchase
  defp parse_order("release"), do: :release

  defp order_path(record_list_params, order) do
    qs =
      record_list_params
      |> Map.take([:query])
      |> Map.put(:order, order)
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/collection?#{qs}"
  end

  defp back_path(record_list_params) do
    qs =
      record_list_params
      |> Map.take([:query, :page, :page_size, :order])
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/collection?#{qs}"
  end
end
