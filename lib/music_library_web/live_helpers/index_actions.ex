defmodule MusicLibraryWeb.LiveHelpers.IndexActions do
  @moduledoc false

  import LiveToast, only: [put_toast: 3]
  import Phoenix.Component, only: [assign: 3]

  import Phoenix.LiveView,
    only: [
      push_patch: 2,
      push_navigate: 2,
      start_async: 3,
      stream: 4,
      stream_delete: 3
    ]

  import MusicLibraryWeb.Components.Pagination, only: [page_to_offset: 2]
  import MusicLibraryWeb.LiveHelpers.Params

  use Gettext, backend: MusicLibraryWeb.Gettext

  alias MusicLibrary.Records

  @doc """
  Applies the :index action. Reads config from `socket.assigns.index_config`
  for context_module, default_order, allowed_orders, and default_records_list_params.

  Returns the socket (not wrapped in `{:noreply, ...}`).
  """
  def apply_index_action(socket, params) do
    config = socket.assigns.index_config

    query = params["query"] || ""
    order = parse_order(params["order"] || config.default_order, config.allowed_orders)
    total_records = config.context_module.search_records_count(query)

    record_list_params =
      config.default_records_list_params
      |> merge_query(query)
      |> merge_order(order)
      |> merge_pagination(params, total_records)

    load_and_assign_records(socket, record_list_params)
  end

  @doc """
  Applies the :import action. Falls back to :index if the stream hasn't
  been initialized yet.

  Returns the socket (not wrapped in `{:noreply, ...}`).
  """
  def apply_import_action(socket, params) do
    config = socket.assigns.index_config
    import_query = params["import_query"] || ""

    socket
    |> apply_fallback_index(params, :records, fn s, :index, p -> apply_index_action(s, p) end)
    |> assign(:page_title, config.import_page_title)
    |> assign(:import_query, import_query)
    |> assign(:record, nil)
  end

  @doc """
  Applies the :edit action. Falls back to :index if the stream hasn't
  been initialized yet.

  Returns the socket (not wrapped in `{:noreply, ...}`).
  """
  def apply_edit_action(socket, %{"id" => id} = params) do
    config = socket.assigns.index_config
    record = Records.get_record!(id)

    socket
    |> apply_fallback_index(params, :records, fn s, :index, p -> apply_index_action(s, p) end)
    |> assign(:page_title, record_page_title(record, config))
    |> assign(:record, record)
  end

  @doc """
  Loads records from the context module and assigns them to the socket stream.

  Returns the socket (not wrapped in `{:noreply, ...}`).
  """
  def load_and_assign_records(socket, record_list_params) do
    config = socket.assigns.index_config
    offset = page_to_offset(record_list_params.page, record_list_params.page_size)

    records =
      config.context_module.search_records(record_list_params.query,
        limit: record_list_params.page_size,
        offset: offset,
        order: record_list_params.order
      )

    socket
    |> assign(:page_title, config.section_page_title)
    |> assign(:record, nil)
    |> assign(:record_list_params, record_list_params)
    |> stream(:records, records, reset: true)
  end

  def handle_delete(socket, id) do
    record = Records.get_record!(id)
    socket = stream_delete(socket, :records, record)

    {:noreply,
     start_async(socket, {:delete_record, id}, fn ->
       Records.delete_record(record)
     end)}
  end

  def handle_search(socket, query) do
    config = socket.assigns.index_config

    qs =
      config.default_records_list_params
      |> Map.put(:query, query)
      |> Map.take([:query, :page, :page_size])

    {:noreply, push_patch(socket, to: config.index_path_fn.(qs))}
  end

  def handle_cart_imported_single(socket, record) do
    config = socket.assigns.index_config

    {:noreply,
     socket
     |> put_toast(:info, config.import_success_toast)
     |> push_navigate(to: config.record_path_fn.(record.id))}
  end

  def handle_cart_imported_async(socket, count) do
    config = socket.assigns.index_config

    msg =
      ngettext(
        "Importing %{count} record in the background...",
        "Importing %{count} records in the background...",
        count,
        count: count
      )

    {:noreply,
     socket
     |> put_toast(:info, msg)
     |> push_patch(to: config.base_index_path)}
  end

  def handle_set_display(socket, mode) do
    mode = parse_mode(mode)

    {:noreply,
     socket
     |> assign(:display, mode)
     |> load_and_assign_records(socket.assigns.record_list_params)}
  end

  def handle_record_saved(socket) do
    {:noreply, load_and_assign_records(socket, socket.assigns.record_list_params)}
  end

  @doc """
  Handles a PubSub notification that records have changed.
  Refreshes total_entries and reloads the record stream using the current parameters.
  """
  def handle_index_changed(socket) do
    config = socket.assigns.index_config
    params = socket.assigns.record_list_params
    total_records = config.context_module.search_records_count(params.query)
    updated_params = %{params | total_entries: total_records}
    load_and_assign_records(socket, updated_params)
  end

  defp record_page_title(record, config) do
    Enum.join(
      [
        Records.Record.artist_names(record),
        "-",
        record.title,
        "·",
        gettext("Edit"),
        "·",
        config.section_page_title
      ],
      " "
    )
  end
end
