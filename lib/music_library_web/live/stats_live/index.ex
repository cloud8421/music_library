defmodule MusicLibraryWeb.StatsLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.StatsLive.DataComponents

  alias MusicLibrary.{Records, Wishlist}
  alias Records.Record

  def mount(_params, _session, socket) do
    collection_count_by_format = Records.count_records_by_format()

    collection_count_by_type = Records.count_records_by_type()

    collection_count =
      Enum.reduce(collection_count_by_format, 0, fn {_, count}, acc -> acc + count end)

    wishlist_count = Wishlist.count()

    latest_record = Records.get_latest_record!()

    recent_tracks = LastFm.Feed.all()

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
       nav_section: :stats
     )}
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
         )
         |> push_patch(to: ~p"/wishlist")}

      {:error, reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Error importing record") <> "," <> inspect(reason))
         |> push_patch(to: ~p"/wishlist")}
    end
  end

  def handle_info(%{tracks: tracks}, socket) do
    {:noreply, stream(socket, :recent_tracks, tracks, reset: true)}
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

  def close_actions_menu(track_id) do
    JS.hide(to: "#actions-#{track_id}")
    |> JS.remove_class("pointer-events-none", to: "#scrobble-activity > li")
  end
end
