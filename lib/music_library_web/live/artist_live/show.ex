defmodule MusicLibraryWeb.ArtistLive.Show do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.Records

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(%{"musicbrainz_id" => musicbrainz_id}, _, socket) do
    artist = Records.get_artist!(musicbrainz_id)

    grouped_artist_records =
      musicbrainz_id
      |> Records.get_artist_records()
      |> group_and_sort()

    {:noreply,
     socket
     |> assign(:nav_section, :artists)
     |> assign(:artist, artist)
     |> assign(:artist_records, grouped_artist_records)
     |> assign_async(:artist_info, fn ->
       with {:ok, artist_info} <- Records.get_artist_info(musicbrainz_id) do
         {:ok, %{artist_info: artist_info}}
       end
     end)
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

  defp group_and_sort(records) do
    {collection, wishlist} = Enum.split_with(records, fn r -> r.purchased_at end)

    %{
      collection: Enum.sort_by(collection, fn r -> r.release end, :desc),
      wishlist: Enum.sort_by(wishlist, fn r -> r.release end, :desc)
    }
  end

  defp render_bio(nil), do: gettext("Biography not available")

  defp render_bio(bio) do
    PhoenixHTMLHelpers.Format.text_to_html(bio,
      escape: false,
      attributes: [class: "mt-4 text-sm/7"]
    )
  end
end
