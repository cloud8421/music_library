defmodule MusicLibraryWeb.CollectionLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.Components.BarcodeScanner, only: [barcode_icon: 1]
  import MusicLibraryWeb.Components.Pagination
  import MusicLibraryWeb.LiveHelpers.Params
  import MusicLibraryWeb.RecordComponents

  alias MusicLibrary.Chats
  alias MusicLibrary.Collection
  alias MusicLibraryWeb.Components.AddRecord
  alias MusicLibraryWeb.LiveHelpers.IndexActions

  defp index_config do
    %{
      context_module: Collection,
      default_order: "purchase",
      allowed_orders: [:purchase, :alphabetical, :release],
      default_records_list_params: %{query: "", page: 1, page_size: 72, order: :purchase},
      purchased_at_fn: fn -> DateTime.utc_now() end,
      import_page_title: gettext("Add new Record · Collection"),
      section_page_title: gettext("Collection"),
      import_success_toast: gettext("Record imported successfully"),
      record_path_fn: fn id -> ~p"/collection/#{id}" end,
      index_path_fn: fn qs -> ~p"/collection?#{qs}" end,
      base_index_path: ~p"/collection"
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_section={@current_section}
      socket={@socket}
      toasts_sync={assigns[:toasts_sync]}
    >
      <header class="mb-2 gap-6">
        <div class="my-2 flex items-center justify-between gap-6">
          <.search_form query={@record_list_params.query} />
          <.button_group>
            <.button
              variant="solid"
              size="sm"
              patch={~p"/collection/import"}
            >
              <.icon name="hero-plus" class="icon" aria-hidden="true" data-slot="icon" />
              <span class="sr-only sm:not-sr-only">{gettext("Add")}</span>
            </.button>
            <.button
              variant="solid"
              size="sm"
              patch={~p"/collection/scan"}
            >
              <.barcode_icon class="icon fill-current" />
              <span class="sr-only sm:not-sr-only">{gettext("Scan")}</span>
            </.button>
            <.button
              variant="solid"
              size="sm"
              phx-click={MusicLibraryWeb.Components.Chat.open("collection-chat-sheet")}
            >
              <.icon
                name="hero-chat-bubble-left-right"
                class="icon"
                aria-hidden="true"
                data-slot="icon"
              />
              <span class="sr-only sm:not-sr-only">{gettext("Chat")}</span>
              <span :if={@chat_count > 0} class="sr-only text-xs font-medium sm:not-sr-only">
                {@chat_count}
              </span>
            </.button>
          </.button_group>
        </div>
      </header>

      <div class="mt-6 flex items-end justify-between gap-6">
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
        width_class="md:max-w-4xl lg:max-w-5xl"
      >
        <.live_component
          module={AddRecord}
          id={:search}
          title={@page_title}
          action={@live_action}
          record={@record}
          patch={back_path(@record_list_params)}
          initial_query={@import_query}
          icon_name="hero-plus"
          purchased_at_fn={@index_config.purchased_at_fn}
        />
      </.structured_modal>

      <.structured_modal
        :if={@live_action == :barcode_scan}
        id="barcode-scanner-modal"
        on_close={JS.patch(back_path(@record_list_params))}
        width_class="md:max-w-4xl lg:max-w-5xl"
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

      <.live_component
        id="collection-chat"
        sheet_id="collection-chat-sheet"
        module={MusicLibraryWeb.Components.Chat}
        title={gettext("Collection")}
        entity={:collection}
        musicbrainz_id={Chats.collection_musicbrainz_id()}
        chat_module={MusicLibrary.Chats.CollectionChat}
        chat_context={@collection_summary}
        placeholder={gettext("Ask about your collection...")}
        empty_prompt={gettext("Ask anything about your music collection")}
      />

      <div
        :if={@open_chat}
        id="auto-open-chat"
        phx-mounted={MusicLibraryWeb.Components.Chat.open("collection-chat-sheet")}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:current_section, :collection)
     |> assign(:index_config, index_config())
     |> assign(:import_query, "")
     |> assign(:display, :grid)
     |> assign(:open_chat, false)
     |> assign(:collection_summary, {"", 0})
     |> assign(:chat_count, Chats.count_chats(:collection, Chats.collection_musicbrainz_id()))
     |> start_async(:collection_summary, &Collection.collection_summary/0)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :import, params) do
    IndexActions.apply_import_action(socket, params)
  end

  defp apply_action(socket, :barcode_scan, params) do
    socket
    |> apply_fallback_index(params, :records, fn s, :index, p ->
      IndexActions.apply_index_action(s, p)
    end)
    |> assign(:page_title, gettext("Scan barcodes · Collection"))
    |> assign(:record, nil)
  end

  defp apply_action(socket, :edit, params) do
    IndexActions.apply_edit_action(socket, params)
  end

  defp apply_action(socket, :index, params) do
    socket
    |> IndexActions.apply_index_action(params)
    |> assign(:open_chat, params["chat"] == "open")
  end

  @impl true
  def handle_info({MusicLibraryWeb.Components.RecordForm, {:saved, _record}}, socket) do
    IndexActions.handle_record_saved(socket)
  end

  def handle_info({AddRecord, {:imported_single, record}}, socket) do
    IndexActions.handle_cart_imported_single(socket, record)
  end

  def handle_info({AddRecord, {:imported_async, count}}, socket) do
    IndexActions.handle_cart_imported_async(socket, count)
  end

  def handle_info({MusicLibraryWeb.Components.Chat, :chats_changed}, socket) do
    chat_count = Chats.count_chats(:collection, Chats.collection_musicbrainz_id())
    {:noreply, assign(socket, :chat_count, chat_count)}
  end

  @impl true
  def handle_async(:collection_summary, {:ok, summary}, socket) do
    {:noreply, assign(socket, :collection_summary, summary)}
  end

  def handle_async(:collection_summary, {:exit, _reason}, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    IndexActions.handle_delete(socket, id)
  end

  def handle_event("search", %{"query" => query}, socket) do
    IndexActions.handle_search(socket, query)
  end

  def handle_event("set_display", %{"mode" => mode}, socket) do
    IndexActions.handle_set_display(socket, mode)
  end

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
