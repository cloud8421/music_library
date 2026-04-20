defmodule MusicLibraryWeb.WishlistLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.Components.Pagination
  import MusicLibraryWeb.RecordComponents

  alias MusicLibrary.Records
  alias MusicLibrary.Wishlist
  alias MusicLibraryWeb.Components.AddRecord
  alias MusicLibraryWeb.LiveHelpers.IndexActions

  defp index_config do
    %{
      context_module: Wishlist,
      default_order: "insertion",
      allowed_orders: [:insertion, :alphabetical, :release],
      default_records_list_params: %{query: "", page: 1, page_size: 72, order: :alphabetical},
      purchased_at_fn: fn -> nil end,
      import_page_title: gettext("Add new Record · Wishlist"),
      section_page_title: gettext("Wishlist"),
      import_success_toast: gettext("Record wishlisted successfully"),
      record_path_fn: fn id -> ~p"/wishlist/#{id}" end,
      index_path_fn: fn qs -> ~p"/wishlist?#{qs}" end,
      base_index_path: ~p"/wishlist"
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
     |> assign(:index_config, index_config())
     |> assign(:import_query, "")
     |> assign(:display, :grid)
     |> assign(:current_date, current_date)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :import, params) do
    IndexActions.apply_import_action(socket, params)
  end

  defp apply_action(socket, :edit, params) do
    IndexActions.apply_edit_action(socket, params)
  end

  defp apply_action(socket, :index, params) do
    IndexActions.apply_index_action(socket, params)
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

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    IndexActions.handle_delete(socket, id)
  end

  def handle_event("search", %{"query" => query}, socket) do
    IndexActions.handle_search(socket, query)
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
    IndexActions.handle_set_display(socket, mode)
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
      |> Map.take([:query, :page, :page_size, :order])
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/wishlist?#{qs}"
  end
end
