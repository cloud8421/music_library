defmodule MusicLibraryWeb.WishlistLive.Index do
  use MusicLibraryWeb, :live_view
  import MusicLibraryWeb.Pagination
  import MusicLibraryWeb.RecordComponents

  alias MusicLibrary.Wishlist
  alias MusicLibrary.Records
  alias MusicLibraryWeb.WishlistLive.Show

  @default_records_list_params %{
    query: "",
    page: 1,
    page_size: 20,
    order: :alphabetical
  }

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if static_changed?(socket) do
        put_flash(socket, :warning, gettext("The application has been updated, please reload."))
      else
        socket
      end

    current_date = DateTime.utc_now() |> DateTime.to_date()

    {:ok,
     socket
     |> assign(nav_section: :wishlist)
     |> assign(:current_date, current_date)}
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
    |> assign(:page_title, gettext("Import from MusicBrainz · Wishlist"))
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

    record = Records.get_record!(id)

    socket
    |> assign(:page_title, Show.page_title(socket.assigns.live_action, record))
    |> assign(:record, record)
  end

  defp apply_action(socket, :index, params) do
    query = params["query"] || ""
    total_records = Wishlist.search_records_count(query)

    record_list_params =
      @default_records_list_params
      |> merge_query(query)
      |> merge_pagination(params, total_records)

    load_and_assign_records(socket, record_list_params)
  end

  @impl true
  def handle_info({MusicLibraryWeb.RecordLive.FormComponent, {:saved, _record}}, socket) do
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
         |> put_flash(:info, gettext("Record imported successfully"))
         |> push_navigate(to: ~p"/wishlist/#{record.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error importing record") <> "," <> inspect(changeset.errors)
         )
         |> push_patch(to: ~p"/wishlist")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Error importing record") <> "," <> inspect(reason))
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
         |> put_flash(:info, gettext("Record added to the collection"))
         |> push_patch(to: ~p"/wishlist")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
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

  defp back_path(record_list_params) do
    qs =
      record_list_params
      |> Map.take([:query, :page, :page_size])
      |> Enum.filter(fn {_, v} -> v not in ["", nil] end)

    ~p"/wishlist?#{qs}"
  end
end
