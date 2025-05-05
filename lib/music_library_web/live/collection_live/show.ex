defmodule MusicLibraryWeb.CollectionLive.Show do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.RecordComponents,
    only: [
      toggle_actions_menu: 1,
      close_actions_menu: 1,
      format_label: 1,
      type_label: 1,
      selected_release_label: 1,
      format_duration: 1
    ]

  alias MusicLibrary.Records
  alias Phoenix.LiveView.JS

  @impl true
  def mount(%{"id" => record_id}, _session, socket) do
    socket =
      if static_changed?(socket) do
        put_flash(socket, :warning, gettext("The application has been updated, please reload."))
      else
        socket
      end

    if connected?(socket) do
      Records.subscribe(record_id)
    end

    {:ok, assign(socket, :release_with_tracks, nil)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    record = Records.get_record!(id)

    socket =
      if record.selected_release_id do
        socket
      else
        socket
      end

    {:noreply,
     socket
     |> assign(:nav_section, :records)
     |> assign(:page_title, page_title(socket.assigns.live_action, record))
     |> assign(:record, record)}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    {:ok, _} = Records.delete_record(record)

    {:noreply, push_navigate(socket, to: ~p"/collection")}
  end

  def handle_event("refresh_musicbrainz_data", %{"id" => id}, socket) do
    record = Records.get_record!(id)

    case Records.refresh_musicbrainz_data(record) do
      {:ok, updated_record} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("MusicBrainz data refreshed successfully"))
         |> assign(:record, updated_record)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error refreshing MusicBrainz data") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("populate_genres", %{"id" => id}, socket) do
    record = Records.get_record!(id)

    case Records.populate_genres(record) do
      {:ok, updated_record} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Genres populated successfully"))
         |> assign(:record, updated_record)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error populating genres") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("refresh_cover", %{"id" => id}, socket) do
    record = Records.get_record!(id)

    case Records.refresh_cover(record) do
      {:ok, record} ->
        {:noreply,
         socket
         |> assign(:record, record)
         |> put_flash(:info, gettext("Cover refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error refreshing cover") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("load_release_with_tracks", _params, socket) do
    selected_release_id = socket.assigns.record.selected_release_id

    {:noreply,
     socket
     |> assign_async(:release_with_tracks, fn ->
       with {:ok, release} <- MusicBrainz.get_release(selected_release_id) do
         {:ok, %{release_with_tracks: MusicBrainz.Release.from_api_response(release)}}
       end
     end)}
  end

  @impl true
  def handle_info({MusicLibraryWeb.FormComponent, {:saved, record}}, socket) do
    {:noreply, assign(socket, :record, record)}
  end

  @impl true
  def handle_info({:update, record}, socket) do
    {:noreply,
     socket
     |> put_flash(:info, gettext("Record updated in the background"))
     |> assign(:record, record)}
  end

  def page_title(:show, record) do
    Enum.join(
      [
        Records.Record.artist_names(record),
        "-",
        record.title,
        "·",
        gettext("Details"),
        "·",
        gettext("Collection")
      ],
      " "
    )
  end

  def page_title(action, record) do
    Enum.join(
      [
        Records.Record.artist_names(record),
        "-",
        record.title,
        "·",
        title_segment(action),
        "·",
        gettext("Collection")
      ],
      " "
    )
  end

  defp title_segment(:show), do: gettext("Show")
  defp title_segment(:edit), do: gettext("Edit")

  defp medium_duration(medium) do
    medium
    |> MusicBrainz.Release.medium_duration()
    |> format_duration()
  end
end
