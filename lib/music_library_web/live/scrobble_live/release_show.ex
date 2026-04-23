defmodule MusicLibraryWeb.ScrobbleLive.ReleaseShow do
  @moduledoc false
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.ScrobbleActivity

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_section={@current_section}
      socket={@socket}
      toasts_sync={assigns[:toasts_sync]}
    >
      <.alert
        :if={not @can_scrobble?}
        color="warning"
        title={gettext("Last.fm not connected")}
        hide_close
      >
        {gettext(
          "You need to connect your Last.fm account to scrobble. Please set up your Last.fm session key in the settings."
        )}
      </.alert>

      <div class="my-4">
        <.button variant="ghost" size="sm" navigate={~p"/scrobble/#{@rg_id}"}>
          <.icon name="hero-arrow-left" class="icon" aria-hidden="true" data-slot="icon" />
          {gettext("Back to releases")}
        </.button>
      </div>

      <.live_component
        id="scrobble-release"
        sheet_id="scrobble-release"
        module={MusicLibraryWeb.Components.Release}
        release_id={@release_id}
        show_print?={false}
        timezone={@timezone}
        on_release_loaded={:release_loaded}
      />
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       current_section: :scrobble,
       can_scrobble?: ScrobbleActivity.can_scrobble?(),
       rg_id: nil,
       release_id: nil,
       page_title: gettext("Scrobble Release")
     )}
  end

  @impl true
  def handle_params(%{"rg_id" => rg_id, "release_id" => release_id}, _url, socket) do
    {:noreply,
     socket
     |> assign(:rg_id, rg_id)
     |> assign(:release_id, release_id)}
  end

  @impl true
  def handle_info({:release_loaded, release}, socket) do
    {:noreply, assign(socket, :page_title, page_title(release))}
  end

  defp page_title(release) do
    Enum.join(
      [
        artist_names(release),
        "-",
        release.title,
        "·",
        gettext("Release"),
        "·",
        gettext("Scrobble Anything")
      ],
      " "
    )
  end

  defp artist_names(release) do
    release.artists
    |> Enum.map_join(fn artist -> artist.name <> (artist.joinphrase || "") end)
    |> String.trim()
  end
end
