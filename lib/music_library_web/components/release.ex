defmodule MusicLibraryWeb.Components.Release do
  use MusicLibraryWeb, :live_component

  require Logger

  alias MusicBrainz.Release
  alias MusicLibrary.Records.TracklistPdf
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
     |> assign(:selected_tracks, MapSet.new())
     |> assign(:pending_form_params, nil)}
  end

  @impl true
  def update(%{release_id: release_id} = assigns, socket) do
    socket = assign(socket, assigns)
    timezone = socket.assigns.timezone
    current_time = DateTime.utc_now() |> DateTime.shift_zone!(timezone)

    {:ok,
     socket
     |> assign(:finished_at, current_time)
     |> assign(:form, to_form(%{"finished_at" => DateTime.to_naive(current_time)}, as: :release))
     |> assign(:release_with_tracks, AsyncResult.loading())
     |> start_async(:release_with_tracks, fn ->
       load_release_with_tracks(release_id)
     end)}
  end

  def update(%{already_scrobbled: _already_scrobbled} = assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def handle_async(:release_with_tracks, {:ok, {:ok, release}}, socket) do
    notify_release_loaded(socket, release)

    socket =
      socket
      |> assign(
        :release_with_tracks,
        AsyncResult.ok(socket.assigns.release_with_tracks, release)
      )
      |> apply_pending_form_params()

    {:noreply, socket}
  end

  def handle_async(:release_with_tracks, {:ok, {:error, reason}}, socket) do
    {:noreply,
     assign(
       socket,
       :release_with_tracks,
       AsyncResult.failed(socket.assigns.release_with_tracks, {:error, reason})
     )}
  end

  def handle_async(:release_with_tracks, {:exit, reason}, socket) do
    {:noreply,
     assign(
       socket,
       :release_with_tracks,
       AsyncResult.failed(socket.assigns.release_with_tracks, {:exit, reason})
     )}
  end

  defp notify_release_loaded(socket, release) do
    case socket.assigns[:on_release_loaded] do
      nil -> :ok
      tag -> send(self(), {tag, release})
    end
  end

  defp apply_pending_form_params(socket) do
    case socket.assigns.pending_form_params do
      nil ->
        socket

      params ->
        release = socket.assigns.release_with_tracks.result
        new_selected = apply_form_params(release, params, socket.assigns.selected_tracks)
        finished_at = parse_finished_at(params["finished_at"], socket.assigns.timezone)

        socket
        |> assign(:selected_tracks, new_selected)
        |> assign(:finished_at, finished_at)
        |> assign(:pending_form_params, nil)
    end
  end

  @spec parse_finished_at(term(), String.t()) :: DateTime.t() | nil
  defp parse_finished_at(nil, _timezone), do: nil
  defp parse_finished_at("", _timezone), do: nil

  defp parse_finished_at(value, timezone) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} ->
        datetime

      {:error, _} ->
        case NaiveDateTime.from_iso8601(value) do
          {:ok, naive} -> DateTime.from_naive!(naive, timezone)
          {:error, _} -> nil
        end
    end
  end

  defp parse_finished_at(_, _), do: nil

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex h-full min-h-0 flex-1 flex-col">
      <.form
        for={@form}
        id={"#{@sheet_id}-form"}
        phx-target={@myself}
        phx-change="validate"
        phx-auto-recover="recover_form"
        class="flex min-h-0 flex-1 flex-col"
      >
        <div class="min-h-0 flex-1 overflow-y-auto px-6 pt-6 pb-4">
          <input type="hidden" name="release[selected_tracks][]" value="" />
          <input type="hidden" name="release[toggle_medium][]" value="" />

          <div class="mt-6 flex flex-wrap items-start justify-between gap-3">
            <div class="min-w-0 flex-1">
              <h2 class="truncate text-lg font-semibold text-zinc-900 dark:text-zinc-100">
                {header_title(@release_with_tracks)}
              </h2>
              <p
                :if={artist_names = header_subtitle(@release_with_tracks)}
                class="truncate text-xs text-zinc-500 dark:text-zinc-400"
              >
                {artist_names}
              </p>
            </div>
            <div class="flex w-full flex-wrap items-center justify-end gap-2 sm:w-auto">
              <.date_time_picker
                :if={@can_scrobble?}
                field={@form[:finished_at]}
                size="sm"
                display_format="%b %-d, %H:%M"
                time_format="24"
                placeholder={gettext("Now")}
                class="flex-1 sm:flex-initial"
              >
                <:inner_prefix class="pl-2 text-zinc-500 dark:text-zinc-400">
                  {gettext("Finished at")}
                </:inner_prefix>
                <:outer_suffix class="pr-2">
                  <.button
                    size="sm"
                    type="button"
                    phx-click="reset_to_now"
                    phx-target={@myself}
                  >
                    {gettext("Now")}
                  </.button>
                </:outer_suffix>
              </.date_time_picker>
              <.button
                :if={@can_scrobble? && @release_with_tracks.ok?}
                type="button"
                variant="solid"
                size="sm"
                disabled={@already_scrobbled}
                phx-click="scrobble_release"
                phx-target={@myself}
                phx-disable-with={gettext("Scrobbling...")}
              >
                <.icon name="hero-play" class="icon" aria-hidden="true" data-slot="icon" />
                <span class="hidden sm:inline">{gettext("Scrobble release")}</span>
                <span class="sm:hidden">{gettext("Release")}</span>
              </.button>
              <.dropdown
                :if={(@show_print? && @release_with_tracks.ok?) || !@can_scrobble?}
                id={"#{@sheet_id}-release-actions"}
                placement="bottom-end"
              >
                <:toggle>
                  <.button type="button" variant="outline" size="sm">
                    <span class="sr-only">{gettext("More actions")}</span>
                    <.icon
                      name="hero-ellipsis-vertical"
                      class="icon"
                      aria-hidden="true"
                      data-slot="icon"
                    />
                  </.button>
                </:toggle>
                <.focus_wrap id={"#{@sheet_id}-release-actions-focus-wrap"}>
                  <.dropdown_link
                    :if={@show_print? && @release_with_tracks.ok?}
                    phx-click="print_tracklist"
                    phx-target={@myself}
                  >
                    <.icon name="hero-printer" class="icon" aria-hidden="true" data-slot="icon" />
                    {gettext("Print tracklist")}
                  </.dropdown_link>
                  <.dropdown_link :if={!@can_scrobble?} href={LastFm.auth_url()}>
                    <.icon name="hero-link" class="icon" aria-hidden="true" data-slot="icon" />
                    {gettext("Connect Last.fm")}
                  </.dropdown_link>
                </.focus_wrap>
              </.dropdown>
            </div>
          </div>

          <div :if={@release_with_tracks} class="mt-4 space-y-4">
            <.async_result :let={release_with_tracks} assign={@release_with_tracks}>
              <:loading>
                <div class="mt-48 flex items-center justify-center">
                  <span class="sr-only">{gettext("Loading release with tracks")}</span>
                  <.loading />
                </div>
              </:loading>
              <:failed :let={_failure}>
                <div class="mt-4 text-sm/5 text-zinc-500 dark:text-zinc-400">
                  <.icon
                    name="hero-exclamation-triangle"
                    class="size-5"
                    aria-hidden="true"
                    data-slot="icon"
                  />
                  {gettext("Error loading tracks")}
                  <.button
                    type="button"
                    variant="ghost"
                    size="xs"
                    phx-click={JS.push("load_release_tracks", target: @myself)}
                    class="ml-2 cursor-pointer"
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
                show_print?={@show_print?}
              />
            </.async_result>
          </div>
        </div>

        <.selection_bar
          :if={@can_scrobble? && @release_with_tracks.ok? && MapSet.size(@selected_tracks) > 0}
          release={@release_with_tracks.result}
          selected_tracks={@selected_tracks}
          already_scrobbled={@already_scrobbled}
          myself={@myself}
        />
      </.form>
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
  attr :show_print?, :boolean, required: true

  def medium(assigns) do
    ~H"""
    <div
      :if={@media_count > 1}
      class="flex items-center justify-between gap-3"
    >
      <label class="md:text-md flex min-w-0 cursor-pointer items-center gap-2 text-sm font-semibold text-zinc-700 dark:text-zinc-300">
        <input
          :if={@can_scrobble?}
          type="checkbox"
          id={"medium-checkbox-#{@medium.number}"}
          name="release[toggle_medium][]"
          value={@medium.number}
          checked={medium_selected?(@medium, @selected_tracks)}
          class="size-4 rounded border-gray-300 bg-gray-100 text-blue-600 focus:ring-2 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:ring-offset-gray-800 dark:focus:ring-blue-600"
        />
        <span class="truncate">{medium_title(@medium)}</span>
        <.badge variant="soft" class="text-xs">
          {@medium.format}
        </.badge>
      </label>
      <div class="flex items-center gap-2">
        <.button
          :if={@can_scrobble?}
          type="button"
          variant="soft"
          size="sm"
          disabled={@already_scrobbled}
          phx-click="scrobble_medium"
          phx-value-number={@medium.number}
          phx-target={@myself}
          phx-disable-with={gettext("Scrobbling...")}
        >
          <.icon name="hero-play" class="icon" aria-hidden="true" data-slot="icon" />
          <span class="hidden sm:inline">{medium_scrobble_label(@medium.format)}</span>
          <span class="sr-only sm:hidden">{medium_scrobble_label(@medium.format)}</span>
        </.button>
        <.dropdown
          :if={@show_print?}
          id={"medium-actions-#{@medium.number}"}
          placement="bottom-end"
        >
          <:toggle>
            <.button type="button" variant="outline" size="sm">
              <span class="sr-only">{gettext("More actions")}</span>
              <.icon
                name="hero-ellipsis-vertical"
                class="icon"
                aria-hidden="true"
                data-slot="icon"
              />
            </.button>
          </:toggle>
          <.focus_wrap id={"medium-actions-#{@medium.number}-focus-wrap"}>
            <.dropdown_link
              phx-click="print_medium_tracklist"
              phx-value-medium-number={@medium.number}
              phx-target={@myself}
            >
              <.icon name="hero-printer" class="icon" aria-hidden="true" data-slot="icon" />
              {gettext("Print tracklist")}
            </.dropdown_link>
          </.focus_wrap>
        </.dropdown>
      </div>
    </div>
    <.track_list
      medium_number={@medium.number}
      tracks={@medium.tracks}
      release_artists={@release_artists}
      selected_tracks={@selected_tracks}
      can_scrobble?={@can_scrobble?}
    />
    <.separator />
    <p class="text-right text-xs text-zinc-700 md:text-sm dark:text-zinc-300">
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

  def track_list(assigns) do
    ~H"""
    <ul id={"disc-#{@medium_number}"} class="table w-full table-auto">
      <li
        :for={track <- @tracks}
        class="list-none leading-5 text-zinc-700 md:mt-4 dark:text-zinc-300"
      >
        <label class="contents cursor-pointer">
          <div class="table-row">
            <span :if={@can_scrobble?} class="table-cell pr-2 align-middle">
              <input
                type="checkbox"
                id={"track-checkbox-#{track.id}"}
                name="release[selected_tracks][]"
                value={track.id}
                checked={MapSet.member?(@selected_tracks, track.id)}
                class="size-4 rounded border-gray-300 bg-gray-100 text-blue-600 focus:ring-2 focus:ring-blue-500 dark:border-gray-600 dark:bg-gray-700 dark:ring-offset-gray-800 dark:focus:ring-blue-600"
              />
            </span>
            <span class="table-cell pr-1 text-right text-xs text-nowrap md:text-sm">
              {track.number || track.position}
            </span>
            <span class="table-cell w-full text-xs/8 font-normal md:text-sm">
              {track.title}
            </span>
            <span class="table-cell pl-2 text-right text-xs md:text-sm">
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

  attr :release, :any, required: true
  attr :selected_tracks, :any, required: true
  attr :already_scrobbled, :boolean, required: true
  attr :myself, :any, required: true

  defp selection_bar(assigns) do
    {count, medium_count, duration_ms} =
      selected_tracks_summary(assigns.release, assigns.selected_tracks)

    assigns =
      assign(assigns,
        count: count,
        medium_count: medium_count,
        duration: Duration.format_duration(duration_ms)
      )

    ~H"""
    <div class="sticky bottom-0 z-10 flex flex-wrap items-center justify-between gap-3 border-t border-zinc-200 bg-white px-6 py-3 shadow-[0_-4px_14px_rgba(0,0,0,0.06)] dark:border-zinc-700 dark:bg-zinc-900">
      <div class="min-w-0 flex-1 leading-tight">
        <p class="text-sm font-semibold text-zinc-900 dark:text-zinc-100">
          {ngettext("%{count} track selected", "%{count} tracks selected", @count, count: @count)}
        </p>
        <p class="text-xs text-zinc-500 dark:text-zinc-400">
          <span :if={@medium_count > 1}>
            {ngettext(
              "across %{count} disc",
              "across %{count} discs",
              @medium_count,
              count: @medium_count
            )} · {@duration}
          </span>
          <span :if={@medium_count <= 1}>{@duration}</span>
        </p>
      </div>
      <.button
        type="button"
        variant="solid"
        size="sm"
        disabled={@already_scrobbled}
        phx-click="scrobble_selected_tracks"
        phx-target={@myself}
        phx-disable-with={gettext("Scrobbling...")}
      >
        <.icon name="hero-play" class="icon" aria-hidden="true" data-slot="icon" />
        {gettext("Scrobble selected")}
      </.button>
    </div>
    """
  end

  defguardp release_loaded?(assigns) when assigns.release_with_tracks.ok?

  @impl true
  def handle_event("scrobble_release", _params, socket) when release_loaded?(socket.assigns) do
    release_with_tracks = socket.assigns.release_with_tracks.result
    finished_at = socket.assigns.finished_at

    case ScrobbleActivity.scrobble_release(release_with_tracks, :finished_at, finished_at) do
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
    finished_at = socket.assigns.finished_at

    case ScrobbleActivity.scrobble_medium(
           number,
           release_with_tracks,
           :finished_at,
           finished_at
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

  def handle_event("validate", %{"release" => params}, socket)
      when release_loaded?(socket.assigns) do
    release = socket.assigns.release_with_tracks.result
    new_selected = apply_form_params(release, params, socket.assigns.selected_tracks)
    finished_at_raw = params["finished_at"]
    finished_at = parse_finished_at(finished_at_raw, socket.assigns.timezone)

    {:noreply,
     socket
     |> assign(:selected_tracks, new_selected)
     |> assign(:finished_at, finished_at)
     |> assign(:form, to_form(%{"finished_at" => finished_at_raw}, as: :release))}
  end

  def handle_event("validate", %{"release" => params}, socket) do
    # Release not yet loaded (e.g., phx-auto-recover fires before async completes).
    # Stash the params; handle_async/3 will apply them once the release is available.
    {:noreply, assign(socket, :pending_form_params, params)}
  end

  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("recover_form", params, socket) do
    handle_event("validate", params, socket)
  end

  def handle_event("reset_to_now", _params, socket) do
    current_time = DateTime.utc_now() |> DateTime.shift_zone!(socket.assigns.timezone)

    {:noreply,
     socket
     |> assign(:finished_at, current_time)
     |> assign(:form, to_form(%{"finished_at" => DateTime.to_naive(current_time)}, as: :release))}
  end

  def handle_event("scrobble_selected_tracks", _params, socket)
      when release_loaded?(socket.assigns) do
    release_with_tracks = socket.assigns.release_with_tracks.result
    selected_track_ids = socket.assigns.selected_tracks

    if MapSet.size(selected_track_ids) == 0 do
      put_toast!(:error, gettext("No tracks selected"))
      {:noreply, socket}
    else
      finished_at = socket.assigns.finished_at

      case ScrobbleActivity.scrobble_tracks(
             selected_track_ids,
             release_with_tracks,
             :finished_at,
             finished_at
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

  def handle_event("print_tracklist", _params, socket) when release_loaded?(socket.assigns) do
    release = socket.assigns.release_with_tracks.result

    case TracklistPdf.generate(release) do
      {:ok, pdf_binary} ->
        filename = "#{release.title} - Tracklist.pdf"

        {:noreply,
         push_event(socket, "music_library:download", %{
           data: Base.encode64(pdf_binary),
           filename: filename,
           content_type: "application/pdf"
         })}

      {:error, reason} ->
        Logger.error("Error generating tracklist PDF: #{inspect(reason)}")

        put_toast!(
          :error,
          gettext("Error generating tracklist PDF") <>
            ": " <> ErrorMessages.friendly_message(reason)
        )

        {:noreply, socket}
    end
  end

  def handle_event("print_tracklist", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("print_medium_tracklist", %{"medium-number" => number}, socket)
      when release_loaded?(socket.assigns) do
    release = socket.assigns.release_with_tracks.result
    {number, ""} = Integer.parse(number)

    case TracklistPdf.generate_medium(release, number) do
      {:ok, pdf_binary} ->
        filename = "#{release.title} - Disc #{number} - Tracklist.pdf"

        {:noreply,
         push_event(socket, "music_library:download", %{
           data: Base.encode64(pdf_binary),
           filename: filename,
           content_type: "application/pdf"
         })}

      {:error, reason} ->
        Logger.error("Error generating medium tracklist PDF: #{inspect(reason)}")

        put_toast!(
          :error,
          gettext("Error generating tracklist PDF") <>
            ": " <> ErrorMessages.friendly_message(reason)
        )

        {:noreply, socket}
    end
  end

  def handle_event("print_medium_tracklist", _params, socket) do
    {:noreply, socket}
  end

  def handle_event("load_release_tracks", _params, socket) do
    selected_release_id = socket.assigns.release_id

    {:noreply,
     socket
     |> assign(:release_with_tracks, AsyncResult.loading())
     |> start_async(:release_with_tracks, fn ->
       load_release_with_tracks(selected_release_id)
     end)}
  end

  defp load_release_with_tracks(release_id) do
    with {:ok, release} <- MusicBrainz.get_release(release_id) do
      {:ok, MusicBrainz.Release.from_api_response(release)}
    end
  end

  @spec medium_selected?(MusicBrainz.Release.Medium.t(), MapSet.t()) :: boolean()
  defp medium_selected?(medium, selected_tracks) do
    medium_track_ids = medium.tracks |> Enum.map(& &1.id) |> MapSet.new()
    MapSet.subset?(medium_track_ids, selected_tracks)
  end

  @doc """
  Applies form params from a track-selection form to produce a new `selected_tracks` MapSet.

  Detects master-toggle transitions (the `release[toggle_medium][]` field) by diffing the
  incoming params against the current server-side `current_selected` MapSet. When a medium's
  master toggle transitions from unchecked to checked, all of its tracks are added; when it
  transitions the other way, all of its tracks are removed.

  Used by both `Release` (as a LiveComponent) and `MusicLibraryWeb.ScrobbleLive.Show` to
  share identical form-driven selection logic.
  """
  @spec apply_form_params(MusicBrainz.Release.t(), map(), MapSet.t()) :: MapSet.t()
  def apply_form_params(release, params, current_selected) do
    form_selected =
      (params["selected_tracks"] || [])
      |> Enum.reject(&(&1 == ""))
      |> MapSet.new()

    toggled_medium_numbers =
      (params["toggle_medium"] || [])
      |> Enum.reject(&(&1 == ""))
      |> Enum.map(&String.to_integer/1)
      |> MapSet.new()

    current_fully_selected =
      for medium <- release.media,
          medium_selected?(medium, current_selected),
          into: MapSet.new(),
          do: medium.number

    Enum.reduce(release.media, form_selected, fn medium, acc ->
      was_fully_selected? = MapSet.member?(current_fully_selected, medium.number)
      is_toggled_now? = MapSet.member?(toggled_medium_numbers, medium.number)
      medium_track_ids = medium.tracks |> Enum.map(& &1.id) |> MapSet.new()

      cond do
        not was_fully_selected? and is_toggled_now? ->
          MapSet.union(acc, medium_track_ids)

        was_fully_selected? and not is_toggled_now? ->
          MapSet.difference(acc, medium_track_ids)

        true ->
          acc
      end
    end)
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

  defp header_title(%AsyncResult{ok?: true, result: release}), do: release.title
  defp header_title(_), do: ""

  defp header_subtitle(%AsyncResult{ok?: true, result: release}) do
    case release.artists do
      [] ->
        nil

      artists ->
        artists
        |> Enum.map_join(fn artist -> artist.name <> (artist.joinphrase || "") end)
        |> String.trim()
        |> case do
          "" -> nil
          names -> names
        end
    end
  end

  defp header_subtitle(_), do: nil

  @spec selected_tracks_summary(MusicBrainz.Release.t(), MapSet.t()) ::
          {non_neg_integer(), non_neg_integer(), non_neg_integer()}
  defp selected_tracks_summary(release, selected_tracks) do
    {count, medium_count, duration_ms} =
      Enum.reduce(release.media, {0, 0, 0}, fn medium, {count, medium_count, duration_ms} ->
        matching =
          Enum.filter(medium.tracks, &MapSet.member?(selected_tracks, &1.id))

        case matching do
          [] ->
            {count, medium_count, duration_ms}

          tracks ->
            tracks_duration = Enum.reduce(tracks, 0, &((&1.length || 0) + &2))
            {count + length(tracks), medium_count + 1, duration_ms + tracks_duration}
        end
      end)

    {count, medium_count, duration_ms}
  end
end
