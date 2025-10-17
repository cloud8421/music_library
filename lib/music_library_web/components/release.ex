defmodule MusicLibraryWeb.Components.Release do
  use MusicLibraryWeb, :live_component
  use Gettext, backend: MusicLibraryWeb.Gettext

  alias MusicBrainz.Release
  alias MusicLibrary.ScrobbleActivity
  alias MusicLibraryWeb.Duration

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
                  class="h-5 w-5"
                  aria-hidden="true"
                  data-slot="icon"
                />
                {gettext("Error loading tracks")}
              </div>
            </:failed>
            <.medium
              :for={medium <- release_with_tracks.media}
              can_scrobble?={@can_scrobble?}
              already_scrobbled={@already_scrobbled}
              medium={medium}
              release_artists={release_with_tracks.artists}
              media_count={MusicBrainz.Release.media_count(release_with_tracks)}
              myself={@myself}
            />
          </.async_result>
        </div>
      </.sheet>
    </div>
    """
  end

  attr :medium, Release.Medium, required: true
  attr :release_artists, :list, required: true
  attr :media_count, :integer, required: true
  attr :can_scrobble?, :boolean, required: true
  attr :already_scrobbled, :boolean, required: true
  attr :myself, :any, required: true

  def medium(assigns) do
    ~H"""
    <div
      :if={@media_count > 1}
      class="flex justify-between items-center gap-4 space-y-4"
    >
      <h4 class="text-sm md:text-md font-semibold text-zinc-700 dark:text-zinc-300">
        {medium_title(@medium)}
      </h4>
      <.button
        :if={@can_scrobble?}
        size="sm"
        disabled={@already_scrobbled}
        phx-click="scrobble_medium"
        phx-value-number={@medium.number}
        phx-target={@myself}
        phx-disable-with={gettext("Scrobbling...")}
      >
        {medium_scrobble_label(@medium.format)}
      </.button>
    </div>
    <.track_list
      medium_number={@medium.number}
      tracks={@medium.tracks}
      release_artists={@release_artists}
    />
    <.separator />
    <p class="text-xs md:text-sm text-right text-zinc-700 dark:text-zinc-300">
      {medium_duration(@medium)}
    </p>
    """
  end

  defp medium_scrobble_label(format) do
    if format && String.contains?(format, "Vinyl") do
      gettext("Scrobble side")
    else
      gettext("Scrobble disc")
    end
  end

  attr :medium_number, :integer, required: true
  attr :tracks, :list, required: true
  attr :release_artists, :list, required: true

  def track_list(assigns) do
    ~H"""
    <ul id={"disc-#{@medium_number}"} class="w-full table table-auto">
      <li
        :for={track <- @tracks}
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
            {track.length && Duration.format_duration(track.length)}
          </span>
        </div>
        <div
          :if={@release_artists !== track.artists}
          class="table-row text-xs md:text-sm"
        >
          <span class="table-cell" />
          <span class="table-cell">
            {Enum.map_join(track.artists, ", ", fn artist -> artist.name end)}
          </span>
        </div>
      </li>
    </ul>
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
    else
      {:noreply, socket |> put_toast(:error, gettext("Error scrobbling release"))}
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
    else
      {:noreply, socket |> put_toast(:error, gettext("Error scrobbling disc"))}
    end
  end

  defp medium_duration(medium) do
    medium
    |> MusicBrainz.Release.medium_duration()
    |> Duration.format_duration()
  end

  defp medium_title(medium) do
    if medium.title === "" do
      gettext("Disc %{no}", %{no: medium.number})
    else
      medium.title
    end
  end
end
