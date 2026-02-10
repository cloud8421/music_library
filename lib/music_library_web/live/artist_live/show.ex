defmodule MusicLibraryWeb.ArtistLive.Show do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.RecordComponents,
    only: [record_grid: 1, country_label: 1, artist_image: 1]

  alias MusicLibrary.{Artists, Records}
  alias MusicLibrary.Artists.ArtistInfo

  attr :country, :map, required: true

  defp country_flag(assigns) do
    ~H"""
    <span>{country_label(@country.code)}</span>
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
      <.badge variant="soft" class="mr-2">{gettext("On Tour")}</.badge>
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

  attr :title, :string, required: true
  attr :artists, :list, required: true

  defp artist_grid(assigns) do
    ~H"""
    <div class="mt-4">
      <header class="flex items-baseline justify-start">
        <h2 class="font-semibold text-base sm:text-lg leading-5 text-zinc-700 dark:text-zinc-300">
          {@title}
        </h2>
      </header>
      <ul
        role="list"
        class="mt-4 grid grid-cols-3 gap-x-4 gap-y-8 sm:grid-cols-4 sm:gap-x-6 lg:grid-cols-6 xl:gap-x-8"
      >
        <li :for={artist <- @artists} class="relative">
          <div
            class="relative cursor-pointer"
            phx-click={
              JS.patch(~p"/artists/#{artist.musicbrainz_id}")
              |> JS.dispatch("music_library:scroll_top")
            }
          >
            <.artist_image
              class="aspect-square object-cover rounded-lg hover:shadow-lg/20"
              artist={artist}
              image_hash={artist.image_data_hash}
            />
          </div>
          <p class="pointer-events-none mt-2 block truncate text-sm font-medium text-zinc-900 dark:text-zinc-300">
            {artist.name}
          </p>
        </li>
      </ul>
    </div>
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
  def handle_event("refresh_artist_info", %{"id" => id}, socket) do
    case Artists.fetch_artist_info(id) do
      {:ok, artist_info} ->
        {:noreply,
         socket
         |> assign(:artist_info, artist_info)
         |> assign(:biography, build_biography(artist_info))
         |> put_toast(:info, gettext("Artist info refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error refreshing artist info") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("refresh_wikipedia_data", %{"id" => id}, socket) do
    case Artists.refresh_wikipedia_data(id) do
      {:ok, artist_info} ->
        {:noreply,
         socket
         |> assign(:artist_info, artist_info)
         |> assign(:biography, build_biography(artist_info))
         |> put_toast(:info, gettext("Wikipedia data refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error refreshing Wikipedia data") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("refresh_artist_image", %{"id" => id}, socket) do
    case Artists.fetch_image(id) do
      {:ok, artist_info} ->
        {:noreply,
         socket
         |> assign(:artist_info, artist_info)
         |> put_toast(:info, gettext("Artist image refreshed successfully"))}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error refreshing artist image") <> "," <> inspect(reason)
         )}
    end
  end

  def handle_event("add-to-collection", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    current_time = DateTime.utc_now()

    case Records.update_record(record, %{"purchased_at" => current_time}) do
      {:ok, _} ->
        {:noreply,
         socket
         |> assign_records(socket.assigns.artist.musicbrainz_id)
         |> put_toast(:info, gettext("Record added to the collection"))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error importing record") <> "," <> inspect(changeset.errors)
         )}
    end
  end

  def handle_event("delete", %{"id" => id}, socket) do
    record = Records.get_record!(id)
    {:ok, _} = Records.delete_record(record)

    {:noreply,
     socket
     |> assign_records(socket.assigns.artist.musicbrainz_id)
     |> put_toast(:info, gettext("Record deleted"))}
  end

  defp apply_action(socket, :show, %{"musicbrainz_id" => musicbrainz_id}) do
    artist = Artists.get_artist!(musicbrainz_id)
    artist_info = Artists.get_artist_info!(musicbrainz_id)

    socket
    |> assign_records(musicbrainz_id)
    |> assign(:current_section, :artists)
    |> assign(:artist, artist)
    |> assign(:artist_info, artist_info)
    |> assign(:biography, build_biography(artist_info))
    |> assign(:external_links, ArtistInfo.external_links(artist_info))
    |> assign(:country, ArtistInfo.country(artist_info))
    |> assign_async(:lastfm_artist_info, fn ->
      with {:ok, lastfm_artist_info} <- LastFm.get_artist_info(artist.musicbrainz_id, artist.name) do
        {:ok, %{lastfm_artist_info: lastfm_artist_info}}
      end
    end)
    |> assign_async(:similar_artists, fn ->
      with {:ok, similar_artists} <- Artists.get_similar_artists(artist) do
        artist_image_hashes = Artists.get_image_hashes(similar_artists)

        similar_artists =
          Enum.map(similar_artists, fn artist ->
            %{artist | image_data_hash: Map.get(artist_image_hashes, artist.musicbrainz_id)}
          end)

        {:ok, %{similar_artists: similar_artists}}
      end
    end)
    |> assign(:page_title, page_title(socket.assigns.live_action, artist))
  end

  defp apply_action(socket, :edit, params) do
    socket =
      if get_in(socket.assigns, [:streams, :collection_records]) == nil do
        socket
        |> apply_action(:show, params)
      else
        socket
      end

    socket
    |> assign(:page_title, gettext("Add more · Artist"))
  end

  defp assign_records(socket, artist_musicbrainz_id) do
    %{collection: collection_records, wishlist: wishlist_records} =
      artist_musicbrainz_id
      |> Records.get_artist_records()
      |> group_and_sort()

    socket
    |> stream(:collection_records, collection_records, reset: true)
    |> stream(:wishlist_records, wishlist_records, reset: true)
    |> assign(:collection_records_count, Enum.count(collection_records))
    |> assign(:wishlist_records_count, Enum.count(wishlist_records))
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

  defp page_title(:edit, artist) do
    Enum.join(
      [
        artist.name,
        "·",
        gettext("Edit")
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

  defp build_biography(artist_info) do
    bio_html = ArtistInfo.wikipedia_bio(artist_info)

    if bio_html do
      %{
        source: "Wikipedia",
        summary_html: ArtistInfo.wikipedia_summary(artist_info),
        bio_html: bio_html,
        url: ArtistInfo.wikipedia_url(artist_info),
        description: ArtistInfo.wikipedia_description(artist_info)
      }
    end
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
