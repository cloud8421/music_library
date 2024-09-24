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
    |> assign(:page_title, "Edit Record")
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
    with {:ok, result} <- MusicLibrary.Records.MusicBrainz.get_release_group(musicbrainz_id),
         {:ok, image_data} <- MusicLibrary.Records.MusicBrainz.get_cover_art(musicbrainz_id) do
      artists_attrs =
        result
        |> get_in(["artist-credit", Access.all(), "artist"])
        |> Enum.map(fn artist ->
          %{
            name: artist["name"],
            musicbrainz_id: artist["id"],
            sort_name: artist["sort-name"],
            disambiguation: artist["disambiguation"]
          }
        end)

      record_attrs = %{
        "musicbrainz_id" => musicbrainz_id,
        "title" => result["title"],
        "artists" => artists_attrs,
        "year" => parse_year(result["first-release-date"]),
        "type" => parse_subtype(result["primary-type"]),
        "genres" => Enum.map(result["genres"], fn g -> g["name"] end),
        "image_url" => "https://coverartarchive.org/release-group/#{musicbrainz_id}/front",
        "image_data" => image_data
      }

      case Records.create_record(record_attrs) do
        {:ok, record} ->
          notify_parent({:saved, record})

          {:noreply,
           socket
           |> put_flash(:info, "Record imported successfully")
           |> push_patch(to: ~p"/records")}

        {:error, %Ecto.Changeset{} = changeset} ->
          {:noreply, assign(socket, form: to_form(changeset))}
      end
    else
      {:error, _} ->
        {:noreply, socket}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})

  defp parse_year(iso_date) when is_binary(iso_date) do
    case Date.from_iso8601(iso_date) do
      {:ok, date} ->
        date.year

      _error ->
        {year, _rest} = Integer.parse(iso_date)
        {:ok, year}
    end
  end

  defp parse_subtype("Album"), do: :album
  defp parse_subtype("EP"), do: :ep
  defp parse_subtype("Live"), do: :live
  defp parse_subtype("Compilation"), do: :compilation
  defp parse_subtype("Single"), do: :single
  defp parse_subtype(_), do: :other

  defp musicbrainz_url(record) do
    "https://musicbrainz.org/release-group/#{record.musicbrainz_id}"
  end
end
