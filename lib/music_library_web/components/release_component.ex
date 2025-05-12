defmodule MusicLibraryWeb.ReleaseComponent do
  use MusicLibraryWeb, :live_component
  use Gettext, backend: MusicLibraryWeb.Gettext

  import MusicLibraryWeb.RecordComponents,
    only: [
      format_duration: 1
    ]

  alias MusicLibrary.ScrobbleActivity

  def open(id), do: Fluxon.open_dialog(id)

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:can_scrobble?, ScrobbleActivity.can_scrobble?())}
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

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.sheet :if={@record.selected_release_id} id={@sheet_id} placement="right">
        <div class="mt-6 flex justify-between items-center gap-4">
          <h3 class="text-lg font-semibold text-zinc-700 dark:text-zinc-300">{gettext("Tracks")}</h3>
          <.button
            :if={@can_scrobble?}
            size="sm"
            phx-click="scrobble_release"
            phx-target={@myself}
            phx-disable-with={gettext("Scrobbling...")}
          >
            {gettext("Scrobble release")}
          </.button>
          <.button :if={!@can_scrobble?} as="link" size="sm" href={LastFm.auth_url()}>
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
                    <span class="table-cell text-xs md:text-sm text-right pr-1">
                      {track.position}
                    </span>
                    <span class="table-cell text-xs md:text-sm font-medium leading-8">
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
          {:noreply,
           socket
           |> put_flash(:info, gettext("Release scrobbled successfully"))}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(
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
          {:noreply,
           socket
           |> put_flash(:info, gettext("Disc scrobbled successfully"))}

        {:error, reason} ->
          {:noreply,
           socket
           |> put_flash(
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
    if medium.title !== "" do
      medium.title
    else
      gettext("Disc %{no}", %{no: medium.number})
    end
  end
end
