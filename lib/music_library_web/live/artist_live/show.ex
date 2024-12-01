defmodule MusicLibraryWeb.ArtistLive.Show do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.Records

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"musicbrainz_id" => musicbrainz_id}, _, socket) do
    {:ok, artist} = Records.get_artist(musicbrainz_id)

    {:noreply,
     socket
     |> assign(:nav_section, :artists)
     |> assign(:artist, artist)
     |> assign(:page_title, page_title(socket.assigns.live_action, artist))}
  end

  defp page_title(:show, artist) do
    Enum.join(
      [
        artist.name,
        "·",
        gettext("Details")
      ],
      " "
    )
  end
end
