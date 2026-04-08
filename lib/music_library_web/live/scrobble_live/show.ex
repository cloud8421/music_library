defmodule MusicLibraryWeb.ScrobbleLive.Show do
  use MusicLibraryWeb, :live_view

  import(MusicLibraryWeb.Components.Release, only: [medium: 1, scrobble_button_label: 1])
  import MusicLibraryWeb.RecordComponents, only: [country_label: 1]

  alias MusicLibrary.ScrobbleActivity
  alias MusicLibraryWeb.ErrorMessages

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_section={@current_section}
      socket={@socket}
      toasts_sync={assigns[:toasts_sync]}
    >
      <div>
        <.alert
          :if={not @can_scrobble}
          color="warning"
          title={gettext("Last.fm not connected")}
          hide_close
        >
          {gettext(
            "You need to connect your Last.fm account to scrobble. Please set up your Last.fm session key in the settings."
          )}
        </.alert>

        <div class="my-4">
          <.button variant="ghost" size="sm" navigate={~p"/scrobble"}>
            <.icon name="hero-arrow-left" class="icon" aria-hidden="true" data-slot="icon" />
            {gettext("Back to search")}
          </.button>
        </div>

        <div class="mt-4 px-4 md:flex md:gap-x-4">
          <div class="drop-shadow-sm md:max-w-152 lg:min-w-152">
            <img
              src={MusicBrainz.Release.thumb_url(@release)}
              alt={"Cover art for #{@release.title}"}
              class="w-full rounded-lg drop-shadow-sm"
              loading="lazy"
              onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
            />
          </div>

          <div class="grow">
            <div class="mt-4 flex items-center justify-between md:mt-0">
              <h1 :if={@release.artists != []} class="text-base/6 font-medium text-zinc-700">
                {@release.artists |> Enum.map(& &1.name) |> Enum.join(", ")}
              </h1>
            </div>
            <h2 class="mt-1 flex text-lg font-semibold text-wrap text-zinc-700 md:text-2xl dark:text-zinc-300">
              {@release.title}
            </h2>

            <div class="mt-4 md:mt-8">
              <dl class="divide-y divide-zinc-100 dark:divide-slate-300/30">
                <.dl_row :if={@release.date} label={gettext("Release Date")}>
                  {@release.date}
                </.dl_row>
                <.dl_row :if={@release.country} label={gettext("Country")}>
                  {country_label(@release.country)} {@release.country}
                </.dl_row>
                <.dl_row :if={@release.barcode} label={gettext("Barcode")}>
                  <code>{@release.barcode}</code>
                </.dl_row>
                <.dl_row :if={@release.catalog_number} label={gettext("Catalog Number")}>
                  <code>{@release.catalog_number}</code>
                </.dl_row>
                <.dl_row :if={@release.media != []} label={gettext("Media")}>
                  {ngettext("1 disc", "%{count} discs", MusicBrainz.Release.media_count(@release))}
                </.dl_row>
              </dl>
            </div>

            <.form
              :if={@release.media != []}
              for={@form}
              id="scrobble-release-form"
              class="mt-6 space-y-4"
              phx-change="validate"
              phx-auto-recover="recover_form"
            >
              <input type="hidden" name="release[selected_tracks][]" value="" />
              <input type="hidden" name="release[toggle_medium][]" value="" />

              <div class="flex items-center justify-between">
                <h3 class="text-lg font-semibold text-zinc-900 dark:text-zinc-200">
                  {gettext("Tracks")}
                </h3>

                <.button
                  :if={@can_scrobble}
                  type="button"
                  variant="soft"
                  size="sm"
                  phx-click={
                    if MapSet.size(@selected_tracks) > 0,
                      do: "scrobble_selected_tracks",
                      else: "scrobble_release"
                  }
                >
                  <span class="sr-only">{scrobble_button_label(@selected_tracks)}</span>
                  <.icon name="hero-play" class="icon" aria-hidden="true" data-slot="icon" />
                </.button>
              </div>

              <.medium
                :for={medium <- @release.media}
                can_scrobble?={@can_scrobble}
                already_scrobbled={false}
                medium={medium}
                release_artists={@release.artists}
                selected_tracks={@selected_tracks}
                media_count={MusicBrainz.Release.media_count(@release)}
                myself={nil}
              />
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       current_section: :scrobble,
       release: nil,
       can_scrobble: ScrobbleActivity.can_scrobble?(),
       page_title: "Scrobble Release",
       selected_tracks: MapSet.new(),
       form: to_form(%{}, as: :release)
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
    case ScrobbleActivity.scrobble_release(
           socket.assigns.release,
           :finished_at,
           DateTime.utc_now()
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
           gettext("Error scrobbling release") <> ": " <> ErrorMessages.friendly_message(reason)
         )}
    end
  end

  def handle_event("scrobble_medium", %{"number" => number}, socket) do
    {number, ""} = Integer.parse(number)

    case ScrobbleActivity.scrobble_medium(
           number,
           socket.assigns.release,
           :finished_at,
           DateTime.utc_now()
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
           gettext("Error scrobbling disc") <> ": " <> ErrorMessages.friendly_message(reason)
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
             :finished_at,
             DateTime.utc_now()
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
             gettext("Error scrobbling selected tracks") <>
               ": " <> ErrorMessages.friendly_message(reason)
           )}
      end
    end
  end

  def handle_event("validate", %{"release" => params}, socket) do
    if socket.assigns.release do
      new_selected =
        MusicLibraryWeb.Components.Release.apply_form_params(
          socket.assigns.release,
          params,
          socket.assigns.selected_tracks
        )

      {:noreply, assign(socket, :selected_tracks, new_selected)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("recover_form", params, socket) do
    handle_event("validate", params, socket)
  end
end
