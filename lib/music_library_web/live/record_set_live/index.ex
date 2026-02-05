defmodule MusicLibraryWeb.RecordSetLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.Components.Pagination

  alias MusicLibrary.RecordSets
  alias MusicLibrary.RecordSets.RecordSet
  alias MusicLibraryWeb.Markdown

  @default_list_params %{
    page: 1,
    page_size: 20,
    query: "",
    order: :updated_at
  }

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
    |> apply_fallback_index(params)
    |> assign(:page_title, gettext("Edit Set"))
    |> assign(:record_set, RecordSets.get_record_set!(id))
  end

  defp apply_action(socket, :new, params) do
    socket
    |> apply_fallback_index(params)
    |> assign(:page_title, gettext("New Set"))
    |> assign(:record_set, %RecordSet{})
  end

  defp apply_action(socket, :add_record, %{"id" => id} = params) do
    socket
    |> apply_fallback_index(params)
    |> assign(:page_title, gettext("Add Record"))
    |> assign(:record_set, RecordSets.get_record_set!(id))
  end

  defp apply_action(socket, :index, params) do
    total_sets = RecordSets.count_record_sets()

    list_params =
      @default_list_params
      |> merge_pagination(params, total_sets)

    load_and_assign_sets(socket, list_params)
  end

  defp apply_fallback_index(socket, params) do
    if get_in(socket.assigns, [:streams, :record_sets]) == nil do
      socket
      |> apply_action(:index, params)
    else
      socket
    end
  end

  defp merge_pagination(params, url_params, total_records) do
    page = parse_page(url_params["page"])
    page_size = parse_page_size(url_params["page_size"])

    params
    |> Map.put(:page, page)
    |> Map.put(:page_size, page_size)
    |> Map.put(:total_records, total_records)
  end

  defp parse_page(nil), do: 1

  defp parse_page(page) when is_binary(page) do
    case Integer.parse(page) do
      {num, ""} when num > 0 -> num
      _ -> 1
    end
  end

  defp parse_page(_), do: 1

  defp parse_page_size(nil), do: 20

  defp parse_page_size(page_size) when is_binary(page_size) do
    case Integer.parse(page_size) do
      {num, ""} when num in [20, 50, 100] -> num
      _ -> 20
    end
  end

  defp parse_page_size(_), do: 20

  defp load_and_assign_sets(socket, list_params) do
    offset = page_to_offset(list_params.page, list_params.page_size)

    sets =
      RecordSets.list_record_sets(
        offset: offset,
        limit: list_params.page_size
      )

    list_params_with_total =
      Map.put(list_params, :total_entries, list_params.total_records)

    socket
    |> assign(:list_params, list_params_with_total)
    |> assign(:page_title, gettext("Record Sets"))
    |> assign(:record_set, nil)
    |> stream(:record_sets, sets, reset: true)
  end

  def back_path(list_params) do
    qs =
      list_params
      |> Map.take([:page, :page_size])

    ~p"/record-sets?#{qs}"
  end

  @impl true
  def handle_info(
        {MusicLibraryWeb.RecordSetLive.Form, {:created, record_set}},
        socket
      ) do
    {:noreply,
     socket
     |> stream_insert(:record_sets, record_set, at: 0)
     |> load_and_assign_sets(socket.assigns.list_params)}
  end

  def handle_info(
        {MusicLibraryWeb.RecordSetLive.Form, {:updated, record_set}},
        socket
      ) do
    {:noreply, stream_insert(socket, :record_sets, record_set)}
  end

  def handle_info(
        {MusicLibraryWeb.RecordSetLive.RecordPicker, {:added, record_set}},
        socket
      ) do
    {:noreply,
     socket
     |> stream_insert(:record_sets, record_set)}
  end

  @impl true
  def handle_event("delete_set", %{"id" => id}, socket) do
    record_set = RecordSets.get_record_set!(id)
    {:ok, _} = RecordSets.delete_record_set(record_set)

    {:noreply,
     socket
     |> stream_delete(:record_sets, record_set)
     |> load_and_assign_sets(socket.assigns.list_params)}
  end

  def handle_event("remove_record", %{"set-id" => set_id, "record-id" => record_id}, socket) do
    record_set = RecordSets.get_record_set!(set_id)
    {:ok, updated_set} = RecordSets.remove_record_from_set(record_set, record_id)

    {:noreply, stream_insert(socket, :record_sets, updated_set)}
  end

  def handle_event("move_up", %{"set-id" => set_id, "record-id" => record_id}, socket) do
    record_set = RecordSets.get_record_set!(set_id)
    {:ok, updated_set} = RecordSets.move_record_in_set(record_set, record_id, :up)

    {:noreply, stream_insert(socket, :record_sets, updated_set)}
  end

  def handle_event("move_down", %{"set-id" => set_id, "record-id" => record_id}, socket) do
    record_set = RecordSets.get_record_set!(set_id)
    {:ok, updated_set} = RecordSets.move_record_in_set(record_set, record_id, :down)

    {:noreply, stream_insert(socket, :record_sets, updated_set)}
  end

  defp render_description(description) do
    description
    |> Markdown.to_html()
    |> raw()
  end
end
