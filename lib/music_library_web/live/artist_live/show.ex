defmodule MusicLibraryWeb.ArtistLive.Show do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.{Artists, Records}
  alias MusicLibrary.Records.ArtistInfo

  import MusicLibraryWeb.RecordComponents,
    only: [record_grid: 1, toggle_actions_menu: 1, close_actions_menu: 1]

  attr :country, :map, required: true

  defp country_flag(assigns) do
    ~H"""
    <span>{Flagmojis.by_iso(@country.code).emoji}</span>
    <span class="sr-only">{@country.name}</span>
    """
  end

  attr :lastfm_artist_info, :map, required: true

  defp on_tour_link(assigns) do
    ~H"""
    <a
      :if={@lastfm_artist_info.on_tour}
      class="flex items-center"
      href={LastFm.Artist.events_url(@lastfm_artist_info)}
      target="_blank"
    >
      <.badge variant="pill" class="mr-2">{gettext("On Tour")}</.badge>
    </a>
    """
  end

  attr :play_count, :integer, required: true

  defp play_count(assigns) do
    ~H"""
    <span :if={@play_count > 0} class="text-xs font-medium text-zinc-700 dark:text-zinc-300 grow">
      {ngettext("1 scrobble", "%{count} scrobbles", @play_count)}
    </span>
    <span :if={@play_count == 0} class="text-xs font-medium text-zinc-700 dark:text-zinc-300 grow">
      {gettext("No scrobbles")}
    </span>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("import", %{"id" => musicbrainz_id, "format" => format}, socket) do
    case Records.import_from_musicbrainz_release_group(musicbrainz_id,
           format: format,
           purchased_at: nil
         ) do
      {:ok, _record} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Record wishlisted successfully"))
         |> push_navigate(to: ~p"/artists/#{socket.assigns.artist.musicbrainz_id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error wishlisting record") <> "," <> inspect(changeset.errors)
         )
         |> push_patch(to: ~p"/artists/#{socket.assigns.artist.musicbrainz_id}")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Error wishlisting record") <> "," <> inspect(reason))
         |> push_patch(to: ~p"/artists/#{socket.assigns.artist.musicbrainz_id}")}
    end
  end

  def handle_event("refresh_artist_info", %{"id" => id}, socket) do
    case Artists.fetch_artist_info(id) do
      {:ok, artist_info} ->
        {:noreply,
         socket
         |> assign(:artist_info, artist_info)
         |> put_flash(:info, gettext("Artist info refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error refreshing artist info") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("refresh_artist_image", %{"id" => id}, socket) do
    case Artists.fetch_image(id) do
      {:ok, artist_info} ->
        {:noreply,
         socket
         |> assign(:artist_info, artist_info)
         |> put_flash(:info, gettext("Artist image refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error refreshing artist image") <> "," <> inspect(reason)
         )}
    end
  end

  defp apply_action(socket, :show, %{"musicbrainz_id" => musicbrainz_id}) do
    artist = Artists.get_artist!(musicbrainz_id)
    artist_info = Artists.get_artist_info!(musicbrainz_id)

    %{collection: collection_records, wishlist: wishlist_records} =
      musicbrainz_id
      |> Records.get_artist_records()
      |> group_and_sort()

    socket
    |> assign(:current_section, :artists)
    |> assign(:artist, artist)
    |> assign(:artist_info, artist_info)
    |> assign(:country, ArtistInfo.country(artist_info))
    |> stream(:collection_records, collection_records, reset: true)
    |> stream(:wishlist_records, wishlist_records, reset: true)
    |> assign(:collection_records_count, Enum.count(collection_records))
    |> assign(:wishlist_records_count, Enum.count(wishlist_records))
    |> assign_async(:lastfm_artist_info, fn ->
      with {:ok, lastfm_artist_info} <- LastFm.get_artist_info(artist.musicbrainz_id, artist.name) do
        {:ok, %{lastfm_artist_info: lastfm_artist_info}}
      end
    end)
    |> assign_async(:similar_artists, fn ->
      with {:ok, similar_artists} <- Artists.get_similar_artists(artist) do
        {:ok, %{similar_artists: similar_artists}}
      end
    end)
    |> assign(:page_title, page_title(socket.assigns.live_action, artist))
  end

  defp apply_action(socket, :import, params) do
    socket =
      if get_in(socket.assigns, [:streams, :collection_records]) == nil do
        socket
        |> apply_action(:show, params)
      else
        socket
      end

    socket
    |> assign(:page_title, gettext("Add more · Artist"))
    |> assign(:initial_query, "arid:#{socket.assigns.artist.musicbrainz_id}")
    |> assign(:record, nil)
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

  defp page_title(:import, artist) do
    Enum.join(
      [
        artist.name,
        "·",
        gettext("Add more")
      ],
      " "
    )
  end

  defp group_and_sort(records) do
    {collection, wishlist} = Enum.split_with(records, fn r -> r.purchased_at end)

    %{
      collection: Enum.sort_by(collection, fn r -> r.release_date end, :desc),
      wishlist: Enum.sort_by(wishlist, fn r -> r.release_date end, :desc)
    }
  end

  # Bios start with text, then a link to read more on Last.fm, followed by a license text.
  # We split the bio at the read more link in order to render the license separately.
  defp render_bio(bio) do
    last_fm_link_regex = ~r/<a.*Read more on Last\.fm<\/a>\.*\s*/

    case String.split(bio, last_fm_link_regex, include_captures: true) do
      [text, link, ""] ->
        reformatted_bio =
          Enum.join(
            [
              text,
              ~s(<p class="mt-4 font-semibold text-zinc-700 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200">#{link}</p>)
            ],
            ""
          )

        PhoenixHTMLHelpers.Format.text_to_html(reformatted_bio,
          escape: false,
          attributes: [class: "mt-2 text-sm/7"]
        )

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

  defp remove_read_more_link(summary) do
    last_fm_link_regex = ~r/<a.*Read more on Last\.fm<\/a>\.*\s*/
    reformatted_summary = String.replace(summary, last_fm_link_regex, "")

    PhoenixHTMLHelpers.Format.text_to_html(reformatted_summary,
      escape: false,
      attributes: [class: "mt-2 text-sm/7"]
    )
  end
end
