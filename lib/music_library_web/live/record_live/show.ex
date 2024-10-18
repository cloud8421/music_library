defmodule MusicLibraryWeb.RecordLive.Show do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.Records

  @impl true
  def mount(_params, _session, socket) do
    back_url =
      if connected?(socket) do
        socket
        |> get_connect_params()
        |> Map.get("_live_referer", ~p"/records")
      else
        ~p"/records"
      end

    socket =
      if static_changed?(socket) do
        put_flash(socket, :warning, "The application has been updated, please reload.")
      else
        socket
      end

    {:ok, assign(socket, :back_url, back_url)}
  end

  @impl true
  def handle_params(%{"id" => id}, _, socket) do
    {:noreply,
     socket
     |> assign(:nav_section, :records)
     |> assign(:page_title, page_title(socket.assigns.live_action))
     |> assign(:record, Records.get_record!(id))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    {:ok, _} = Records.delete_record(record)

    {:noreply, push_navigate(socket, to: ~p"/records")}
  end

  defp page_title(:show), do: "Show Record"
  defp page_title(:edit), do: "Edit"

  defp musicbrainz_url(record) do
    "https://musicbrainz.org/release-group/#{record.musicbrainz_id}"
  end
end
