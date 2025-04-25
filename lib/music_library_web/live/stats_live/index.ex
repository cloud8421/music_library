defmodule MusicLibraryWeb.StatsLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]
  import MusicLibraryWeb.ChartComponents

  alias MusicLibrary.{Collection, Records, ScrobbleActivity, Wishlist}

  attr :record, MusicLibrary.Records.Record, required: true
  attr :title, :string, required: true
  attr :class, :string

  defp album_preview(assigns) do
    ~H"""
    <div
      class={[
        "relative overflow-hidden rounded-md bg-white dark:bg-zinc-800 px-4 pb-3 pt-5 shadow-sm sm:px-6 sm:pt-6 cursor-pointer",
        @class
      ]}
      phx-click={JS.navigate(~p"/collection/#{@record}")}
    >
      <dt>
        <img
          class="absolute w-20 rounded-md shadow-sm"
          src={~p"/covers/#{@record.id}?vsn=#{@record.cover_hash}"}
          alt={@record.title}
        />
        <p class="ml-24 truncate text-xs sm:text-sm font-medium text-zinc-500 dark:text-zinc-400">
          {@title}
        </p>
      </dt>
      <dd class="ml-24 flex items-baseline pb-4 sm:pb-6">
        <p class="font-semibold">
          <span class="text-sm md:text-base lg:text-2xl block text-zinc-900 dark:text-zinc-300">
            {@record.title}
          </span>
          <.link
            :for={artist <- @record.artists}
            class="text-sm md:text-base text-zinc-600 dark:text-zinc-200 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200"
            navigate={~p"/artists/#{artist.musicbrainz_id}"}
          >
            {artist.name}
          </.link>
        </p>
      </dd>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :path, :string, required: true

  defp counter(assigns) do
    ~H"""
    <div class="overflow-hidden rounded-md bg-white dark:bg-zinc-800 px-4 pb-3 pt-5 shadow-sm sm:px-6 sm:pt-6">
      <dt class="sm:mt-3">
        <p class="truncate text-sm font-medium text-center text-zinc-500 dark:text-zinc-400">
          {@title}
        </p>
      </dt>
      <dd class="mt-1">
        <.link
          navigate={@path}
          class="block text-2xl sm:text-3xl font-semibold text-center text-zinc-900 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200"
        >
          {@count}
        </.link>
      </dd>
    </div>
    """
  end

  def mount(_params, _session, socket) do
    latest_record = Collection.get_latest_record!()
    recent_tracks = LastFm.get_scrobbled_tracks()
    records_by_artists = Collection.count_records_by_artist(limit: 20)
    records_by_genre = Collection.count_records_by_genre(limit: 20)

    if connected?(socket) do
      LastFm.subscribe_to_feed()
    end

    {:ok,
     socket
     |> assign(:timezone, resolve_timezone!())
     |> stream_configure(:recent_tracks,
       dom_id: fn track -> "track-#{track.scrobbled_at_uts}" end
     )
     |> stream_configure(:recent_albums,
       dom_id: fn album -> "album-#{album.scrobbled_at_uts}" end
     )
     |> assign_counts()
     |> assign_scrobble_activity(recent_tracks)
     |> assign(
       scrobble_activity_mode: :albums,
       latest_record: latest_record,
       page_title: gettext("Stats"),
       nav_section: :stats,
       records_by_artist: records_by_artists,
       records_by_genre: records_by_genre
     )}
  end

  def handle_event("refresh_lastfm_feed", _, socket) do
    LastFm.refresh_scrobbled_tracks()
    {:noreply, socket}
  end

  def handle_event("import", %{"id" => musicbrainz_id, "format" => format}, socket) do
    case Records.import_from_musicbrainz_release(musicbrainz_id,
           format: format,
           purchased_at: nil
         ) do
      {:ok, record} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Record wishlisted successfully"))
         |> push_navigate(to: ~p"/wishlist/#{record.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error wishlisting record") <> "," <> inspect(changeset.errors)
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Error wishlisting record") <> "," <> inspect(reason))}
    end
  end

  def handle_event("set_scrobble_activity_mode", %{"mode" => mode}, socket)
      when mode in ["tracks", "albums"] do
    recent_tracks = LastFm.get_scrobbled_tracks()

    {:noreply,
     socket
     |> assign_scrobble_activity(recent_tracks)
     |> assign(scrobble_activity_mode: String.to_existing_atom(mode))}
  end

  def handle_info(%{tracks: recent_tracks}, socket) do
    {:noreply,
     socket
     |> assign_scrobble_activity(recent_tracks)}
  end

  defp assign_counts(socket) do
    collection_count_by_format = Collection.count_records_by_format()

    collection_count_by_type = Collection.count_records_by_type()

    collection_count =
      Enum.sum_by(collection_count_by_format, fn {_, count} -> count end)

    wishlist_count = Wishlist.count()

    assign(socket,
      collection_count_by_format: collection_count_by_format,
      collection_count_by_type: collection_count_by_type,
      collection_count: collection_count,
      wishlist_count: wishlist_count
    )
  end

  defp assign_scrobble_activity(socket, recent_tracks) do
    %{
      localized_recent_tracks: localized_recent_tracks,
      localized_recent_albums: recent_albums,
      collected_releases: collected_releases,
      wishlisted_releases: wishlisted_releases,
      artist_ids: artist_ids
    } = ScrobbleActivity.from_recent_tracks(recent_tracks, socket.assigns.timezone)

    socket
    |> stream(:recent_tracks, localized_recent_tracks, reset: true)
    |> stream(:recent_albums, recent_albums, reset: true)
    |> assign(
      collected_releases: collected_releases,
      wishlisted_releases: wishlisted_releases,
      artist_ids: artist_ids
    )
  end

  defp tracked_record?(tracked_releases, release_id) do
    Enum.find_value(tracked_releases, fn tracked_release ->
      if tracked_release.release_id == release_id, do: tracked_release.record_id
    end)
  end

  # The Tailwind build step requires all needed classes to be explicitly referenced
  # in the source code, and not dynamically generated. This implies that one cannot
  # (for example) interpolate a number in a class name.
  defp stats_class(collection) do
    case Enum.count(collection) do
      1 -> "grid-cols-1"
      2 -> "grid-cols-2"
      3 -> "grid-cols-3"
      4 -> "grid-cols-4"
      5 -> "grid-cols-5"
      6 -> "grid-cols-6"
      7 -> "grid-cols-7"
      8 -> "grid-cols-8"
      9 -> "grid-cols-9"
      _other -> ""
    end
  end

  defp format_scrobbled_at_uts(uts) do
    uts
    |> DateTime.from_unix!()
    |> DateTime.to_iso8601()
  end

  defp toggle_actions_menu(track_id) do
    JS.toggle(to: "#actions-#{track_id}")
    |> JS.toggle_class("pointer-events-none", to: "#scrobble-activity > li")
  end

  defp close_actions_menu(track_id) do
    JS.hide(to: "#actions-#{track_id}")
    |> JS.remove_class("pointer-events-none", to: "#scrobble-activity > li")
  end

  defp resolve_timezone! do
    Application.get_env(:music_library, MusicLibraryWeb)
    |> Keyword.fetch!(:timezone)
  end
end
