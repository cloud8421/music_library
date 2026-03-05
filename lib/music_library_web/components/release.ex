defmodule MusicLibraryWeb.Components.Release do
  use MusicLibraryWeb, :live_component

  require Logger

  alias MusicBrainz.Release
  alias MusicLibrary.ScrobbleActivity
  alias MusicLibraryWeb.Duration
  alias MusicLibraryWeb.ErrorMessages
  alias Phoenix.LiveView.AsyncResult

  def open(id), do: Fluxon.open_dialog(id)

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:can_scrobble?, ScrobbleActivity.can_scrobble?())
     |> assign(:release_with_tracks, AsyncResult.loading())
     |> assign(:already_scrobbled, false)
     |> assign(:selected_tracks, MapSet.new())}
  end

  @impl true
  def update(%{record: record} = assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_async(:release_with_tracks, fn ->
       with {:ok, release} <- load_release_with_tracks(record.selected_release_id) do
         {:ok, %{release_with_tracks: release}}
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
          <label class="text-lg font-semibold text-zinc-700 dark:text-zinc-300 cursor-pointer">
            <input
              :if={
                @can_scrobble? && @release_with_tracks.ok? &&
                  Release.media_count(@release_with_tracks.result) == 1
              }
              type="checkbox"
              id="medium-checkbox-1"
              checked={
                medium_selected?(
                  Release.get_medium(@release_with_tracks.result, 1),
                  @selected_tracks
                )
              }
              phx-click="toggle_medium"
              phx-value-medium-number={1}
              phx-target={@myself}
              class="w-4 h-4 mr-2 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
            />
            {gettext("Tracks")}
          </label>
          <.button
            :if={@can_scrobble? && @release_with_tracks.ok?}
            size="sm"
            disabled={@already_scrobbled}
            phx-click={
              if MapSet.size(@selected_tracks) > 0,
                do: "scrobble_selected_tracks",
                else: "scrobble_release"
            }
            phx-target={@myself}
            phx-disable-with={gettext("Scrobbling...")}
          >
            {scrobble_button_label(@selected_tracks)}
          </.button>
          <.button :if={!@can_scrobble?} size="sm" href={LastFm.auth_url()}>
            {gettext("Connect your Last.fm account")}
          </.button>
        </div>

        <div :if={@release_with_tracks} class="space-y-4 mt-4">
          <.async_result :let={release_with_tracks} assign={@release_with_tracks}>
            <:loading>
              <div class="flex items-center justify-center mt-48">
                <span class="sr-only">{gettext("Loading release with tracks")}</span>
                <.loading />
              </div>
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
                <.button
                  variant="ghost"
                  size="xs"
                  phx-click={JS.push("load_release_tracks", target: @myself)}
                  class="ml-2  cursor-pointer"
                >
                  {gettext("Retry")}
                </.button>
              </div>
            </:failed>
            <.medium
              :for={medium <- release_with_tracks.media}
              can_scrobble?={@can_scrobble?}
              already_scrobbled={@already_scrobbled}
              medium={medium}
              release_artists={release_with_tracks.artists}
              media_count={MusicBrainz.Release.media_count(release_with_tracks)}
              selected_tracks={@selected_tracks}
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
  attr :selected_tracks, :any, required: true
  attr :myself, :any, required: true

  def medium(assigns) do
    ~H"""
    <div
      :if={@media_count > 1}
      class="flex justify-between items-center gap-4"
    >
      <label class="text-sm md:text-md font-semibold text-zinc-700 dark:text-zinc-300 cursor-pointer">
        <input
          :if={@can_scrobble?}
          type="checkbox"
          id={"medium-checkbox-#{@medium.number}"}
          checked={medium_selected?(@medium, @selected_tracks)}
          phx-click="toggle_medium"
          phx-value-medium-number={@medium.number}
          phx-target={@myself}
          class="w-4 h-4 mr-2 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
        />
        {medium_title(@medium)}
        <.badge variant="soft" class="text-xs">
          {@medium.format}
        </.badge>
      </label>
      <.button
        :if={@can_scrobble?}
        size="sm"
        disabled={@already_scrobbled || MapSet.size(@selected_tracks) > 0}
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
      selected_tracks={@selected_tracks}
      can_scrobble?={@can_scrobble?}
      myself={@myself}
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
  attr :selected_tracks, :any, required: true
  attr :can_scrobble?, :boolean, required: true
  attr :myself, :any, required: true

  def track_list(assigns) do
    ~H"""
    <ul id={"disc-#{@medium_number}"} class="w-full table table-auto">
      <li
        :for={track <- @tracks}
        class="leading-5 text-zinc-700 dark:text-zinc-300 list-none"
      >
        <label class="contents cursor-pointer">
          <div class="table-row">
            <span :if={@can_scrobble?} class="table-cell pr-2 align-middle">
              <input
                type="checkbox"
                id={"track-checkbox-#{track.id}"}
                checked={MapSet.member?(@selected_tracks, track.id)}
                phx-click="toggle_track"
                phx-value-track-id={track.id}
                phx-target={@myself}
                class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
              />
            </span>
            <span class="table-cell text-xs text-right pr-1 text-nowrap">
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
            <span :if={@can_scrobble?} class="table-cell" />
            <span class="table-cell" />
            <span class="table-cell">
              {Enum.map_join(track.artists, ", ", fn artist -> artist.name end)}
            </span>
          </div>
        </label>
      </li>
    </ul>
    """
  end

  defguardp release_loaded?(assigns) when assigns.release_with_tracks.ok?

  @impl true
  def handle_event("scrobble_release", _params, socket) when release_loaded?(socket.assigns) do
    release_with_tracks = socket.assigns.release_with_tracks.result

    case ScrobbleActivity.scrobble_release(release_with_tracks, finished_at: DateTime.utc_now()) do
      {:ok, _} ->
        send_update_after(socket.assigns.myself, %{already_scrobbled: false}, 3000)
        put_toast!(:info, gettext("Release scrobbled successfully"))

        {:noreply, socket |> assign(:already_scrobbled, true)}

      {:error, reason} ->
        Logger.error("Error scrobbling release: #{inspect(reason)}")

        put_toast!(
          :error,
          gettext("Error scrobbling release") <> ": " <> ErrorMessages.friendly_message(reason)
        )

        {:noreply, socket}
    end
  end

  def handle_event("scrobble_release", _params, socket) do
    put_toast!(:error, gettext("Error scrobbling release"))
    {:noreply, socket}
  end

  def handle_event("scrobble_medium", %{"number" => number}, socket)
      when release_loaded?(socket.assigns) do
    release_with_tracks = socket.assigns.release_with_tracks.result
    {number, ""} = Integer.parse(number)

    case ScrobbleActivity.scrobble_medium(number, release_with_tracks,
           finished_at: DateTime.utc_now()
         ) do
      {:ok, _} ->
        send_update_after(socket.assigns.myself, %{already_scrobbled: false}, 3000)
        put_toast!(:info, gettext("Disc scrobbled successfully"))

        {:noreply, socket |> assign(:already_scrobbled, true)}

      {:error, reason} ->
        Logger.error("Error scrobbling medium: #{inspect(reason)}")

        put_toast!(
          :error,
          gettext("Error scrobbling disc") <> ": " <> ErrorMessages.friendly_message(reason)
        )

        {:noreply, socket}
    end
  end

  def handle_event("scrobble_medium", _params, socket) do
    put_toast!(:error, gettext("Error scrobbling disc"))
    {:noreply, socket}
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

  def handle_event("toggle_medium", %{"medium-number" => number}, socket) do
    {number, ""} = Integer.parse(number)
    selected_tracks = socket.assigns.selected_tracks
    release_with_tracks = socket.assigns.release_with_tracks.result

    medium_tracks =
      release_with_tracks
      |> Release.medium_tracks(number)
      |> Enum.map(& &1.id)
      |> MapSet.new()

    updated_tracks =
      if MapSet.subset?(medium_tracks, selected_tracks) do
        MapSet.difference(selected_tracks, medium_tracks)
      else
        MapSet.union(selected_tracks, medium_tracks)
      end

    {:noreply, assign(socket, :selected_tracks, updated_tracks)}
  end

  def handle_event("scrobble_selected_tracks", _params, socket)
      when release_loaded?(socket.assigns) do
    release_with_tracks = socket.assigns.release_with_tracks.result
    selected_track_ids = socket.assigns.selected_tracks

    if MapSet.size(selected_track_ids) == 0 do
      put_toast!(:error, gettext("No tracks selected"))
      {:noreply, socket}
    else
      case ScrobbleActivity.scrobble_tracks(
             selected_track_ids,
             release_with_tracks,
             finished_at: DateTime.utc_now()
           ) do
        {:ok, _} ->
          send_update_after(socket.assigns.myself, %{already_scrobbled: false}, 3000)
          put_toast!(:info, gettext("Selected tracks scrobbled successfully"))

          {:noreply,
           socket
           |> assign(:already_scrobbled, true)
           |> assign(:selected_tracks, MapSet.new())}

        {:error, reason} ->
          Logger.error("Error scrobbling tracks: #{inspect(reason)}")

          put_toast!(
            :error,
            gettext("Error scrobbling selected tracks") <>
              ": " <> ErrorMessages.friendly_message(reason)
          )

          {:noreply, socket}
      end
    end
  end

  def handle_event("scrobble_selected_tracks", _params, socket) do
    put_toast!(:error, gettext("Error scrobbling selected tracks"))
    {:noreply, socket}
  end

  def handle_event("load_release_tracks", _params, socket) do
    selected_release_id = socket.assigns.record.selected_release_id

    {:noreply,
     socket
     |> assign_async(:release_with_tracks, fn ->
       with {:ok, release} <- load_release_with_tracks(selected_release_id) do
         {:ok, %{release_with_tracks: release}}
       end
     end)}
  end

  defp load_release_with_tracks(release_id) do
    with {:ok, release} <- MusicBrainz.get_release(release_id) do
      {:ok, MusicBrainz.Release.from_api_response(release)}
    end
  end

  defp medium_selected?(medium, selected_tracks) do
    medium_track_ids = medium.tracks |> Enum.map(& &1.id) |> MapSet.new()
    MapSet.subset?(medium_track_ids, selected_tracks)
  end

  def scrobble_button_label(selected_tracks) do
    if MapSet.size(selected_tracks) > 0 do
      gettext("Scrobble selected tracks")
    else
      gettext("Scrobble release")
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
