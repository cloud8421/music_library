defmodule MusicLibraryWeb.RecordLive.Index do
  use MusicLibraryWeb, :live_view
  import MusicLibraryWeb.Pagination

  alias MusicLibrary.Records

  @default_records_list_params %{
    query: "",
    page: 1,
    page_size: 100
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if static_changed?(socket) do
        put_flash(socket, :warning, "The application has been updated, please reload.")
      else
        socket
      end

    {:ok, assign(socket, :nav_section, :records)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :import, params) do
    socket =
      if get_in(socket.assigns, [:streams, :records]) == nil do
        socket
        |> apply_action(:index, params)
      else
        socket
      end

    socket
    |> assign(:page_title, "Import from MusicBrainz")
    |> assign(:record, nil)
  end

  defp apply_action(socket, :edit, params = %{"id" => id}) do
    socket =
      if get_in(socket.assigns, [:streams, :records]) == nil do
        socket
        |> apply_action(:index, params)
      else
        socket
      end

    socket
    |> assign(:page_title, "Edit Metadata")
    |> assign(:record, Records.get_record!(id))
  end

  defp apply_action(socket, :index, params) do
    query = params["query"] || ""
    total_records = Records.search_records_count(query)

    record_list_params =
      @default_records_list_params
      |> merge_query(query)
      |> merge_pagination(params, total_records)

    offset = page_to_offset(record_list_params.page, record_list_params.page_size)
    records = Records.search_records(query, limit: record_list_params.page_size, offset: offset)

    socket
    |> assign(:page_title, "Collection")
    |> assign(:record, nil)
    |> assign(:record_list_params, record_list_params)
    |> stream(:records, records, reset: true)
  end

  @impl true
  def handle_info({MusicLibraryWeb.RecordLive.FormComponent, {:saved, record}}, socket) do
    {:noreply, stream_insert(socket, :records, record)}
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
      |> URI.encode_query()

    {:noreply, push_patch(socket, to: ~s"/records?#{qs}")}
  end

  def handle_event("import", %{"id" => musicbrainz_id, "format" => format}, socket) do
    case Records.import_from_musicbrainz(musicbrainz_id, format: format) do
      {:ok, record} ->
        {:noreply,
         socket
         |> put_flash(:info, "Record imported successfully")
         |> push_navigate(to: ~p"/records/#{record.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Error importing record, #{inspect(reason)}")
         |> push_patch(to: ~p"/records")}
    end
  end

  defp merge_query(record_list_params, nil), do: record_list_params

  defp merge_query(record_list_params, query) do
    Map.put(record_list_params, :query, query)
  end

  defp merge_pagination(record_list_params, params, total_records) do
    record_list_params
    |> Map.put(:page, parse_int_or_default(params["page"], record_list_params.page))
    |> Map.put(
      :page_size,
      parse_int_or_default(params["page_size"], record_list_params.page_size)
    )
    |> Map.put(:total_entries, total_records)
  end

  defp parse_int_or_default(nil, default), do: default

  defp parse_int_or_default(value, _default) when is_binary(value) do
    String.to_integer(value)
  end

  defp musicbrainz_url(record) do
    "https://musicbrainz.org/release-group/#{record.musicbrainz_id}"
  end
end
