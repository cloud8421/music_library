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

  defp bio_available?(artist_info_result) do
    artist_info_result.ok? && artist_info_result.result && artist_info_result.result.bio !== ""
  end

  defp played?(artist_info_result) do
    artist_info_result.ok? && artist_info_result.result &&
      artist_info_result.result.play_count > 0
  end

  # Bios start with text, then a link to read more on Last.fm, followed by a license text.
  # We split the bio at the read more link in order to render the license separately.
  @last_fm_link_regex ~r/<a.*Read more on Last\.fm<\/a>\.\s*/
  defp render_bio(bio) do
    case String.split(bio, @last_fm_link_regex, include_captures: true) do
      [text, link, license] ->
        reformatted_bio =
          Enum.join(
            [
              text,
              ~s(<p class="mt-4 font-semibold text-zinc-700 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200">#{link}</p>),
              ~s(<p class="mt-4 italic block">#{license}</p>)
            ],
            ""
          )

        PhoenixHTMLHelpers.Format.text_to_html(reformatted_bio,
          escape: false,
          attributes: [class: "mt-2 text-sm/7"]
        )

      other ->
        PhoenixHTMLHelpers.Format.text_to_html(other,
          escape: false,
          attributes: [class: "mt-2 text-sm/7"]
        )
    end
  end
end
