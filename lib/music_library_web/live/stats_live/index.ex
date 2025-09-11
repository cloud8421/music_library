defmodule MusicLibraryWeb.StatsLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibrary.FormatNumber, only: [to_compact: 1]
  import MusicLibraryWeb.ChartComponents
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]
  import MusicLibraryWeb.StatsComponents

  alias MusicLibrary.{Collection, Records, ScrobbleActivity, Wishlist}
  alias MusicLibraryWeb.StatsLive.{TopAlbums, TopArtists}

  def mount(_params, _session, socket) do
    current_date = Date.utc_today()
    latest_record = Collection.get_latest_record!()
    recent_tracks = LastFm.get_scrobbled_tracks(50)
    records_by_artists = Collection.count_records_by_artist(limit: 20)
    records_by_genre = Collection.count_records_by_genre(limit: 20)
    records_on_this_day = Collection.get_records_on_this_day(current_date)

    if connected?(socket) do
      LastFm.subscribe_to_feed()
    end

    {:ok,
     socket
     |> stream_configure(:recent_tracks,
       dom_id: fn track -> "track-#{track.scrobbled_at_uts}" end
     )
     |> stream_configure(:recent_albums,
       dom_id: fn album -> "album-#{album.scrobbled_at_uts}" end
     )
     |> stream(:records_on_this_day, records_on_this_day, reset: true)
     |> assign_counts()
     |> assign_scrobble_activity(recent_tracks)
     |> assign(
       current_date: current_date,
       scrobble_activity_mode: "albums",
       latest_record: latest_record,
       page_title: gettext("Stats"),
       current_section: :stats,
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
         |> put_toast(:info, gettext("Record wishlisted successfully"))
         |> push_navigate(to: ~p"/wishlist/#{record.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error wishlisting record") <> "," <> inspect(changeset.errors)
         )}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(:error, gettext("Error wishlisting record") <> "," <> inspect(reason))}
    end
  end

  def handle_event("set_scrobble_activity_mode", %{"mode" => mode}, socket)
      when mode in ["tracks", "albums"] do
    {:noreply,
     socket
     |> assign(scrobble_activity_mode: mode)}
  end

  def handle_event("set_current_date", %{"current_date" => current_date}, socket) do
    case Date.from_iso8601(current_date) do
      {:ok, date} ->
        records_on_this_day = Collection.get_records_on_this_day(date)

        {:noreply,
         socket
         |> assign(:current_date, date)
         |> stream(:records_on_this_day, records_on_this_day, reset: true)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_info(%{track_count: 0}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{track_count: _count}, socket) do
    recent_tracks = LastFm.get_scrobbled_tracks()

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

    scrobble_count = ScrobbleActivity.scrobble_count()

    last_updated_uts =
      if track = List.first(localized_recent_tracks) do
        track.scrobbled_at_uts
      end

    socket
    |> assign(:last_updated_uts, last_updated_uts)
    |> assign(:scrobble_count, scrobble_count)
    |> stream(:recent_tracks, localized_recent_tracks, reset: true)
    |> stream(:recent_albums, recent_albums, reset: true)
    |> assign(
      collected_releases: collected_releases,
      wishlisted_releases: wishlisted_releases,
      artist_ids: artist_ids
    )
  end

  defp format_scrobbled_at_uts(uts) do
    uts
    |> DateTime.from_unix!()
    |> DateTime.to_iso8601()
  end
end
