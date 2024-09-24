defmodule MusicLibraryWeb.RecordLive.Index do
  use MusicLibraryWeb, :live_view
  import MusicLibraryWeb.Pagination

  alias MusicLibrary.Records

  @impl true
  def mount(params, _session, socket) do
    total_records = Records.count_records()

    pagination_params = get_pagination_params(params, total_records)
    offset = page_to_offset(pagination_params.page, pagination_params.page_size)
    records = Records.list_records(limit: pagination_params.page_size, offset: offset)

    {:ok,
     socket
     |> assign(:pagination_params, pagination_params)
     |> stream(:records, records)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :search, _params) do
    socket
    |> assign(:page_title, "Search Records")
    |> assign(:record, nil)
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    socket
    |> assign(:page_title, "Edit Metadata")
    |> assign(:record, Records.get_record!(id))
  end

  defp apply_action(socket, :index, params) do
    new_socket =
      socket
      |> assign(:page_title, "Listing Records")
      |> assign(:record, nil)

    total_records = Records.count_records()
    pagination_params = get_pagination_params(params, total_records)

    if pagination_params != socket.assigns.pagination_params do
      offset = page_to_offset(pagination_params.page, pagination_params.page_size)
      records = Records.list_records(limit: pagination_params.page_size, offset: offset)

      new_socket
      |> assign(:pagination_params, pagination_params)
      |> stream(:records, records, reset: true)
    else
      new_socket
    end
  end

  @impl true
  def handle_info({MusicLibraryWeb.RecordLive.FormComponent, {:saved, record}}, socket) do
    {:noreply, stream_insert(socket, :records, record)}
  end

  def handle_info({__MODULE__, {:saved, record}}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/records/#{record}")}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    {:ok, _} = Records.delete_record(record)

    {:noreply, stream_delete(socket, :records, record)}
  end

  def handle_event("import", %{"id" => musicbrainz_id}, socket) do
    case Records.import_from_musicbrainz(musicbrainz_id) do
      {:ok, record} ->
        notify_parent({:saved, record})

        {:noreply,
         socket
         |> put_flash(:info, "Record imported successfully")
         |> push_patch(to: ~p"/records")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error importing record, #{inspect(reason)}")
         |> push_patch(to: ~p"/records")}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp musicbrainz_url(record) do
    "https://musicbrainz.org/release-group/#{record.musicbrainz_id}"
  end
end
