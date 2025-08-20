defmodule MusicLibraryWeb.ReleaseComponent do
  use MusicLibraryWeb, :live_component
  use Gettext, backend: MusicLibraryWeb.Gettext

  alias MusicLibrary.ScrobbleActivity

  def open(id), do: Fluxon.open_dialog(id)

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:can_scrobble?, ScrobbleActivity.can_scrobble?())
     |> assign(:already_scrobbled, false)}
  end

  @impl true
  def update(%{record: record} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_async(:release_with_tracks, fn ->
       with {:ok, release} <- MusicBrainz.get_release(record.selected_release_id) do
         {:ok, %{release_with_tracks: MusicBrainz.Release.from_api_response(release)}}
       end
     end)}
  end

  def update(%{already_scrobbled: _already_scrobbled} = assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.sheet
        :if={@record.selected_release_id}
        id={@sheet_id}
        placement="right"
        class="min-w-xs sm:min-w-sm"
      >
        <div class="mt-6 flex justify-between items-center gap-4">
          <h3 class="text-lg font-semibold text-zinc-700 dark:text-zinc-300">{gettext("Tracks")}</h3>
          <.button
            :if={@can_scrobble?}
            size="sm"
            disabled={@already_scrobbled}
            phx-click="scrobble_release"
            phx-target={@myself}
            phx-disable-with={gettext("Scrobbling...")}
          >
            {gettext("Scrobble release")}
          </.button>
          <.button :if={!@can_scrobble?} size="sm" href={LastFm.auth_url()}>
            {gettext("Connect your Last.fm account")}
          </.button>
        </div>

        <div :if={@release_with_tracks} class="space-y-4 mt-4">
          <.async_result :let={release_with_tracks} assign={@release_with_tracks}>
            <:loading>
              <span class="sr-only">{gettext("Loading release with tracks")}</span>
              <.loading />
            </:loading>
            <:failed :let={_failure}>
              <div class="mt-4 text-sm leading-5 text-zinc-500 dark:text-zinc-400">
                <.icon
                  name="hero-exclamation-triangle"
                  class="-mt-1 mr-1 h-5 w-5"
                  aria-hidden="true"
                  data-slot="icon"
                />
                {gettext("Error loading tracks")}
              </div>
            </:failed>
            <div :for={medium <- release_with_tracks.media} class="space-y-4">
              <div
                :if={MusicBrainz.Release.media_count(release_with_tracks) > 1}
                class="flex justify-between items-center gap-4"
              >
                <h4 class="text-sm md:text-md font-semibold text-zinc-700 dark:text-zinc-300">
                  {medium_title(medium)}
                </h4>
                <.button
                  :if={@can_scrobble?}
                  size="sm"
                  disabled={@already_scrobbled}
                  phx-click="scrobble_medium"
                  phx-value-number={medium.number}
                  phx-target={@myself}
                  phx-disable-with={gettext("Scrobbling...")}
                >
                  {gettext("Scrobble disc")}
                </.button>
              </div>
              <ul id={"disc-#{medium.number}"} class="w-full table table-auto">
                <li
                  :for={track <- medium.tracks}
                  class="contents leading-5 text-zinc-700 dark:text-zinc-300 list-none"
                >
                  <div class="table-row">
                    <span class="table-cell text-xs text-right pr-1">
                      {track.number || track.position}
                    </span>
                    <span class="table-cell text-xs md:text-sm font-medium leading-8 w-full">
                      {track.title}
                    </span>
                    <span class="table-cell text-xs md:text-sm text-right pl-2">
                      {track.length && format_duration(track.length)}
                    </span>
                  </div>
                  <div
                    :if={release_with_tracks.artists !== track.artists}
                    class="table-row text-xs md:text-sm"
                  >
                    <span class="table-cell" />
                    <span class="table-cell">
                      {Enum.map_join(track.artists, ", ", fn artist -> artist.name end)}
                    </span>
                  </div>
                </li>
              </ul>
              <.separator />
              <p class="text-xs md:text-sm text-right text-zinc-700 dark:text-zinc-300">
                {medium_duration(medium)}
              </p>
            </div>
          </.async_result>
        </div>
      </.sheet>
    </div>
    """
  end

  @impl true
  def handle_event("scrobble_release", _params, socket) do
    release_with_tracks_async_result =
      socket.assigns.release_with_tracks

    if release_with_tracks =
         release_with_tracks_async_result && release_with_tracks_async_result.result do
      case ScrobbleActivity.scrobble_release(release_with_tracks, finished_at: DateTime.utc_now()) do
        {:ok, _} ->
          send_update_after(socket.assigns.myself, %{already_scrobbled: false}, 3000)

          {:noreply,
           socket
           |> assign(:already_scrobbled, true)
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
  end

  def handle_event("scrobble_medium", %{"number" => number}, socket) do
    release_with_tracks_async_result =
      socket.assigns.release_with_tracks

    number = String.to_integer(number)

    if release_with_tracks =
         release_with_tracks_async_result && release_with_tracks_async_result.result do
      case ScrobbleActivity.scrobble_medium(number, release_with_tracks,
             finished_at: DateTime.utc_now()
           ) do
        {:ok, _} ->
          send_update_after(socket.assigns.myself, %{already_scrobbled: false}, 3000)

          {:noreply,
           socket
           |> assign(:already_scrobbled, true)
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
  end

  defp medium_duration(medium) do
    medium
    |> MusicBrainz.Release.medium_duration()
    |> format_duration()
  end

  defp medium_title(medium) do
    if medium.title === "" do
      gettext("Disc %{no}", %{no: medium.number})
    else
      medium.title
    end
  end

  defp format_duration(milliseconds) do
    milliseconds
    |> System.convert_time_unit(:millisecond, :second)
    |> format_seconds()
  end

  defp format_seconds(seconds) when seconds <= 59 do
    "0:#{zero_pad(seconds)}"
  end

  defp format_seconds(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    format_minutes(minutes, remaining_seconds)
  end

  defp format_minutes(minutes, seconds) when minutes <= 59 do
    "#{minutes}:#{zero_pad(seconds)}"
  end

  defp format_minutes(minutes, seconds) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)

    format_hours(hours, remaining_minutes, seconds)
  end

  defp format_hours(hours, minutes, seconds) do
    "#{hours}:#{zero_pad(minutes)}:#{zero_pad(seconds)}"
  end

  defp zero_pad(integer) do
    integer
    |> to_string()
    |> String.pad_leading(2, "0")
  end
end
