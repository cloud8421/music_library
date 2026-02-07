defmodule MusicLibraryWeb.RecordSetLive.Show do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.RecordComponents, only: [artist_links: 1]

  alias MusicLibrary.RecordSets
  alias MusicLibrary.RecordSets.RecordSet
  alias MusicLibraryWeb.Markdown
  alias Phoenix.LiveView.JS

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
    {:ok, _} = RecordSets.delete_record_set(socket.assigns.record_set)

    {:noreply, push_navigate(socket, to: ~p"/record-sets")}
  end

  def handle_event("remove_record", %{"record-id" => record_id}, socket) do
    {:ok, updated_set} =
      RecordSets.remove_record_from_set(socket.assigns.record_set, record_id)

    {:noreply, assign(socket, :record_set, updated_set)}
  end

  def handle_event("move_up", %{"record-id" => record_id}, socket) do
    {:ok, updated_set} =
      RecordSets.move_record_in_set(socket.assigns.record_set, record_id, :up)

    {:noreply, assign(socket, :record_set, updated_set)}
  end

  def handle_event("move_down", %{"record-id" => record_id}, socket) do
    {:ok, updated_set} =
      RecordSets.move_record_in_set(socket.assigns.record_set, record_id, :down)

    {:noreply, assign(socket, :record_set, updated_set)}
  end

  defp page_title(:show, record_set), do: record_set.name
  defp page_title(:edit, record_set), do: gettext("Edit") <> " · " <> record_set.name
  defp page_title(:add_record, record_set), do: gettext("Add Record") <> " · " <> record_set.name

  defp render_description(description) do
    description
    |> Markdown.to_html()
    |> raw()
  end
end
