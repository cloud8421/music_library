defmodule MusicLibraryWeb.StatsLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.DataComponents
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias MusicLibrary.{Artists, Collection, Records, Wishlist}

  def mount(_params, _session, socket) do
    latest_record = Collection.get_latest_record!()
    recent_tracks = LastFm.Feed.all_tracks()

    if connected?(socket) do
      LastFm.Feed.subscribe()
    end

    {:ok,
     socket
     |> stream_configure(:recent_tracks,
       dom_id: fn track -> "track-#{track.scrobbled_at_uts}" end
     )
     |> stream_configure(:recent_albums,
       dom_id: fn album -> "album-#{album.scrobbled_at_uts}" end
     )
     |> assign_counts()
     |> assign_scrobble_activity(recent_tracks)
     |> assign(
       scrobble_activity_mode: :tracks,
       latest_record: latest_record,
       page_title: gettext("Stats"),
       nav_section: :stats
     )}
  end

  def handle_event("refresh_lastfm_feed", _, socket) do
    LastFm.Refresh.refresh()
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
         |> put_flash(:info, gettext("Record imported successfully"))
         |> push_navigate(to: ~p"/wishlist/#{record.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           gettext("Error importing record") <> "," <> inspect(changeset.errors)
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Error importing record") <> "," <> inspect(reason))}
    end
  end

  def handle_event("set_scrobble_activity_mode", %{"mode" => mode}, socket)
      when mode in ["tracks", "albums"] do
    recent_tracks = LastFm.Feed.all_tracks()

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
    recent_release_ids = recent_release_ids(recent_tracks)

    collected_releases = Collection.collected_releases(recent_release_ids)
    wishlisted_releases = Wishlist.wishlisted_releases(recent_release_ids)

    all_artist_ids = Artists.get_all_artist_ids()
    recent_artist_ids = recent_artist_ids(recent_tracks)
    artist_ids = MapSet.intersection(all_artist_ids, recent_artist_ids)

    recent_albums =
      recent_tracks
      |> Enum.uniq_by(fn t -> t.album end)
      |> Enum.map(fn t ->
        %{
          scrobbled_at_uts: t.scrobbled_at_uts,
          scrobbled_at_label: t.scrobbled_at_label,
          metadata: t.album,
          artist: t.artist,
          cover_url: t.cover_url
        }
      end)

    socket
    |> stream(:recent_tracks, recent_tracks, reset: true)
    |> stream(:recent_albums, recent_albums, reset: true)
    |> assign(
      collected_releases: collected_releases,
      wishlisted_releases: wishlisted_releases,
      artist_ids: artist_ids
    )
  end

  defp recent_release_ids(recent_tracks) do
    recent_tracks
    |> Enum.map(fn t -> t.album.musicbrainz_id end)
    |> Enum.uniq()
    |> Enum.reject(fn musicbrainz_id -> musicbrainz_id == "" end)
  end

  def recent_artist_ids(recent_tracks) do
    recent_tracks
    |> Enum.map(fn t -> t.artist.musicbrainz_id end)
    |> Enum.uniq()
    |> Enum.reject(fn musicbrainz_id -> musicbrainz_id == "" end)
    |> MapSet.new()
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
end
