defmodule MusicLibraryWeb.RecordSetLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.Components.Pagination
  import MusicLibraryWeb.LiveHelpers.Params
  import MusicLibraryWeb.RecordComponents, only: [artist_links: 1]

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

  defp apply_fallback_index(socket, params) do
    if socket.assigns[:record_sets] == nil do
      socket
      |> apply_action(:index, params)
    else
      socket
    end
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
    |> assign(:record_sets, sets)
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

  def handle_event("move_up", %{"set-id" => set_id, "record-id" => record_id}, socket) do
    record_set = RecordSets.get_record_set!(set_id)
    {:ok, updated_set} = RecordSets.move_record_in_set(record_set, record_id, :up)

    {:noreply, update_record_set_in_list(socket, updated_set)}
  end

  def handle_event("move_down", %{"set-id" => set_id, "record-id" => record_id}, socket) do
    record_set = RecordSets.get_record_set!(set_id)
    {:ok, updated_set} = RecordSets.move_record_in_set(record_set, record_id, :down)

    {:noreply, update_record_set_in_list(socket, updated_set)}
  end

  def handle_event("reorder", %{"set_id" => set_id, "record_ids" => record_ids}, socket) do
    record_set = RecordSets.get_record_set!(set_id)
    {:ok, updated_set} = RecordSets.reorder_records_in_set(record_set, record_ids)

    {:noreply, update_record_set_in_list(socket, updated_set)}
  end

  defp update_record_set_in_list(socket, updated_set) do
    record_sets =
      Enum.map(socket.assigns.record_sets, fn set ->
        if set.id == updated_set.id, do: updated_set, else: set
      end)

    assign(socket, :record_sets, record_sets)
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

  defp render_description(description) do
    description
    |> Markdown.to_html()
    |> raw()
  end
end
