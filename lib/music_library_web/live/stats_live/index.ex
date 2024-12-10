defmodule MusicLibraryWeb.StatsLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.StatsLive.DataComponents

  alias MusicLibrary.{Collection, Records, Wishlist}
  alias Records.Record

  def mount(_params, _session, socket) do
    collection_count_by_format = Collection.count_records_by_format()

    collection_count_by_type = Collection.count_records_by_type()

    collection_count =
      Enum.reduce(collection_count_by_format, 0, fn {_, count}, acc -> acc + count end)

    wishlist_count = Wishlist.count()

    latest_record = Collection.get_latest_record!()

    recent_tracks = LastFm.Feed.all_tracks()

    release_ids = release_ids(recent_tracks)

    collected_release_ids = Collection.collected_release_ids(release_ids)
    wishlisted_release_ids = Wishlist.wishlisted_release_ids(release_ids)

    artist_ids = Records.get_all_artist_ids()

    if connected?(socket) do
      LastFm.Feed.subscribe()
    end

    {:ok,
     socket
     |> stream_configure(:recent_tracks,
       dom_id: fn track -> "track-#{track.scrobbled_at_uts}" end
     )
     |> stream(:recent_tracks, recent_tracks)
     |> assign(
       page_title: gettext("Stats"),
       collection_count_by_format: collection_count_by_format,
       collection_count_by_type: collection_count_by_type,
       collection_count: collection_count,
       wishlist_count: wishlist_count,
       latest_record: latest_record,
       collected_release_ids: collected_release_ids,
       wishlisted_release_ids: wishlisted_release_ids,
       artist_ids: artist_ids,
       nav_section: :stats
     )}
  end

  def handle_event("refresh_lastfm_feed", _, socket) do
    LastFm.Refresh.refresh()
    {:noreply, socket}
  end

  def handle_info(%{tracks: recent_tracks}, socket) do
    release_ids = release_ids(recent_tracks)

    collected_release_ids = Collection.collected_release_ids(release_ids)
    wishlisted_release_ids = Wishlist.wishlisted_release_ids(release_ids)

    artist_ids = Records.get_all_artist_ids()

    {:noreply,
     socket
     |> assign(
       collected_release_ids: collected_release_ids,
       wishlisted_release_ids: wishlisted_release_ids,
       artist_ids: artist_ids
     )
     |> stream(:recent_tracks, recent_tracks, reset: true)}
  end

  defp release_ids(recent_tracks) do
    recent_tracks
    |> Enum.map(fn t -> t.album.musicbrainz_id end)
    |> Enum.uniq()
    |> Enum.reject(fn musicbrainz_id -> musicbrainz_id == "" end)
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
