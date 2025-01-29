defmodule MusicLibraryWeb.CollectionLive.Show do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.RecordComponents,
    only: [toggle_actions_menu: 1, close_actions_menu: 1, format_label: 1, type_label: 1]

  alias Phoenix.LiveView.JS
  alias MusicLibrary.Records

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if static_changed?(socket) do
        put_flash(socket, :warning, gettext("The application has been updated, please reload."))
      else
        socket
      end

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    record = Records.get_record!(id)

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
      {:ok, updated_record} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Cover refreshed successfully"))
         |> assign(:record, updated_record)}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error refreshing cover") <> "," <> inspect(reason)
         )}
    end
  end

  @impl true
  def handle_info({MusicLibraryWeb.RecordLive.FormComponent, {:saved, record}}, socket) do
    {:noreply, assign(socket, :record, record)}
  end

  def page_title(:show, record) do
    artist_names = Enum.map(record.artists, & &1.name)

    Enum.join(
      [
        Enum.join(artist_names, ", "),
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
    artist_names = Enum.map(record.artists, & &1.name)

    Enum.join(
      [
        Enum.join(artist_names, ", "),
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
end
