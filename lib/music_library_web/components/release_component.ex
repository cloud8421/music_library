defmodule MusicLibraryWeb.ReleaseComponent do
  use MusicLibraryWeb, :live_component
  use Gettext, backend: MusicLibraryWeb.Gettext

  import MusicLibraryWeb.RecordComponents,
    only: [
      format_duration: 1
    ]

  alias MusicLibrary.ScrobbleActivity

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:can_scrobble?, ScrobbleActivity.can_scrobble?())
     |> assign(:release_with_tracks, nil)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <Fluxon.Components.Sheet.sheet
        :if={@record.selected_release_id}
        id={@sheet_id}
        placement="right"
        on_open={JS.push("load_release_with_tracks", target: @myself)}
      >
        <div class="mt-6 flex justify-between items-center gap-4">
          <h3 class="text-lg font-semibold text-zinc-700 dark:text-zinc-300">{gettext("Tracks")}</h3>
          <Fluxon.Components.Button.button
            :if={@can_scrobble?}
            size="xs"
            phx-click="scrobble_release"
            phx-target={@myself}
            phx-disable-with={gettext("Scrobbling...")}
          >
            <span class="sr-only">{gettext("Scrobble release")}</span>
            <.last_fm_icon class="w-4 fill-current" />
          </Fluxon.Components.Button.button>
          <Fluxon.Components.Button.button
            :if={!@can_scrobble?}
            as="link"
            size="xs"
            href={LastFm.auth_url()}
          >
            {gettext("Connect your Last.fm account")}
          </Fluxon.Components.Button.button>
        </div>

        <div :if={@release_with_tracks} class="space-y-4 mt-4">
          <.async_result :let={release_with_tracks} assign={@release_with_tracks}>
            <:loading>
              <span class="sr-only">{gettext("Loading release with tracks")}</span>
              <Fluxon.Components.Loading.loading />
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
              <h4
                :if={MusicBrainz.Release.media_count(release_with_tracks) > 1}
                class="text-sm font-semibold text-zinc-700 dark:text-zinc-300"
              >
                {medium_title(medium)}
              </h4>
              <ul id={"disc-#{medium.number}"} class="w-full table table-auto">
                <li
                  :for={track <- medium.tracks}
                  class="contents leading-5 text-zinc-700 dark:text-zinc-300 list-none"
                >
                  <div class="table-row">
                    <span class="table-cell text-xs text-right pr-1">{track.position}</span>
                    <span class="table-cell text-xs font-medium leading-8">{track.title}</span>
                    <span class="table-cell text-xs text-right pl-2">
                      {track.length && format_duration(track.length)}
                    </span>
                  </div>
                  <div :if={release_with_tracks.artists !== track.artists} class="table-row text-xs">
                    <span class="table-cell" />
                    <span class="table-cell">
                      {Enum.map_join(track.artists, ", ", fn artist -> artist.name end)}
                    </span>
                  </div>
                </li>
              </ul>
              <Fluxon.Components.Separator.separator />
              <p class="text-xs text-right text-zinc-700 dark:text-zinc-300">
                {medium_duration(medium)}
              </p>
            </div>
          </.async_result>
        </div>
      </Fluxon.Components.Sheet.sheet>
    </div>
    """
  end

  @impl true
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

  def handle_event("scrobble_release", _params, socket) do
    release_with_tracks_async_result =
      socket.assigns.release_with_tracks

    if release_with_tracks =
         release_with_tracks_async_result && release_with_tracks_async_result.result do
      case ScrobbleActivity.scrobble(release_with_tracks, finished_at: DateTime.utc_now()) do
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

  attr :class, :string, required: true

  defp last_fm_icon(assigns) do
    # https://www.svgrepo.com/svg/341982/last-fm
    ~H"""
    <svg class={@class} width="24" height="24" viewBox="0 0 32 32">
      <path d="M14.131 22.948l-1.172-3.193c0 0-1.912 2.131-4.771 2.131-2.537 0-4.333-2.203-4.333-5.729 0-4.511 2.276-6.125 4.515-6.125 3.224 0 4.245 2.089 5.125 4.772l1.161 3.667c1.161 3.561 3.365 6.421 9.713 6.421 4.548 0 7.631-1.391 7.631-5.068 0-2.968-1.697-4.511-4.844-5.244l-2.344-0.511c-1.624-0.371-2.104-1.032-2.104-2.131 0-1.249 0.985-1.984 2.604-1.984 1.767 0 2.704 0.661 2.865 2.24l3.661-0.444c-0.297-3.301-2.584-4.656-6.323-4.656-3.308 0-6.532 1.251-6.532 5.245 0 2.5 1.204 4.077 4.245 4.807l2.484 0.589c1.865 0.443 2.484 1.224 2.484 2.287 0 1.359-1.323 1.921-3.828 1.921-3.703 0-5.244-1.943-6.124-4.625l-1.204-3.667c-1.541-4.765-4.005-6.531-8.891-6.531-5.287-0.016-8.151 3.385-8.151 9.192 0 5.573 2.864 8.595 8.005 8.595 4.14 0 6.125-1.943 6.125-1.943z" />
    </svg>
    """
  end
end
