defmodule MusicLibraryWeb.ScrobbleLive.Show do
  use MusicLibraryWeb, :live_view

  import(MusicLibraryWeb.Components.Release, only: [medium: 1, scrobble_button_label: 1])
  import MusicLibraryWeb.RecordComponents, only: [country_label: 1]

  alias MusicLibrary.ScrobbleActivity

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       current_section: :scrobble,
       release: nil,
       can_scrobble: ScrobbleActivity.can_scrobble?(),
       page_title: "Scrobble Release",
       selected_tracks: MapSet.new()
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    apply_action(socket, socket.assigns.live_action, params)
  end

  defp apply_action(socket, :show, %{"release_id" => release_id}) do
    case MusicBrainz.get_release(release_id) do
      {:ok, release} ->
        release = MusicBrainz.Release.from_api_response(release)

        {:noreply,
         assign(socket,
           release: release,
           page_title: "Scrobble: #{release.title}"
         )}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to fetch release details")
         |> push_navigate(to: ~p"/scrobble")}
    end
  end

  @impl true
  def handle_event("scrobble_release", _params, socket) do
    case ScrobbleActivity.scrobble_release(socket.assigns.release,
           finished_at: DateTime.utc_now()
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Release scrobbled successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error scrobbling release") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("scrobble_medium", %{"medium_number" => number}, socket) do
    number = String.to_integer(number)

    case ScrobbleActivity.scrobble_medium(number, socket.assigns.release,
           finished_at: DateTime.utc_now()
         ) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_toast(:info, gettext("Disc scrobbled successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error scrobbling disc") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("scrobble_selected_tracks", _params, socket) do
    release_with_tracks = socket.assigns.release
    selected_track_ids = socket.assigns.selected_tracks

    if MapSet.size(selected_track_ids) == 0 do
      {:noreply, socket |> put_toast(:error, gettext("No tracks selected"))}
    else
      case ScrobbleActivity.scrobble_tracks(
             selected_track_ids,
             release_with_tracks,
             finished_at: DateTime.utc_now()
           ) do
        {:ok, _} ->
          {:noreply,
           socket
           |> assign(:selected_tracks, MapSet.new())
           |> put_toast(:info, gettext("Selected tracks scrobbled successfully"))}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_toast(
             :error,
             gettext("Error scrobbling selected tracks") <> "," <> inspect(reason)
           )}
      end
    end
  end

  def handle_event("toggle_track", %{"track-id" => track_id}, socket) do
    selected_tracks = socket.assigns.selected_tracks

    updated_tracks =
      if MapSet.member?(selected_tracks, track_id) do
        MapSet.delete(selected_tracks, track_id)
      else
        MapSet.put(selected_tracks, track_id)
      end

    {:noreply, assign(socket, :selected_tracks, updated_tracks)}
  end
end
