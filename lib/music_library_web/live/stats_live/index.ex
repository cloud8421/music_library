defmodule MusicLibraryWeb.StatsLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibrary.FormatNumber, only: [to_compact: 1]
  import MusicLibraryWeb.ChartComponents
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]
  import MusicLibraryWeb.StatsComponents
  import MusicLibraryWeb.ScrobbleComponents

  alias MusicLibrary.Assets.Transform
  alias MusicLibrary.{Collection, Records, ScrobbleActivity, Wishlist}
  alias MusicLibraryWeb.StatsLive.{TopAlbums, TopArtists}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <div>
        <h1 class="mt-5 text-base lg:text-2xl text-zinc-900 dark:text-zinc-200 font-semibold">
          {gettext("Records")}
        </h1>
        <dl class="mt-5 grid grid-cols-3 gap-5 sm:grid-cols-5">
          <.album_preview
            record={@latest_record}
            title={gettext("Latest purchase")}
            class="col-span-3 sm:col-span-2"
          />
          <.counter
            title={gettext("Collection")}
            count={@collection_count}
            path={~p"/collection"}
          />
          <.counter title={gettext("Wishlist")} count={@wishlist_count} path={~p"/wishlist"} />
          <.counter
            title={gettext("Scrobbles")}
            count={to_compact(@scrobble_count)}
            tooltip={@scrobble_count}
          />
        </dl>
      </div>

      <div class="grid lg:grid-cols-2 gap-x-5">
        <div>
          <h1 class="mt-5 text-base lg:text-2xl text-zinc-900 dark:text-zinc-200 font-semibold">
            {gettext("Formats")}
          </h1>
          <.counters_by_category
            categories_with_counts={@collection_count_by_format}
            category_format_fn={&format_label/1}
            category_path_fn={fn format -> ~p"/collection?query=format:#{format}" end}
          />
        </div>

        <div>
          <h1 class="mt-5 text-base lg:text-2xl text-zinc-900 dark:text-zinc-200 font-semibold">
            {gettext("Types")}
          </h1>
          <.counters_by_category
            categories_with_counts={@collection_count_by_type}
            category_format_fn={&type_label/1}
            category_path_fn={fn type -> ~p"/collection?query=type:#{type}" end}
          />
        </div>
      </div>

      <div>
        <div class="mt-5 grid grid-cols-1 lg:grid-cols-2 gap-5">
          <TopArtists.live id="top-artists" timezone={@timezone} last_updated_uts={@last_updated_uts} />
          <TopAlbums.live id="top-albums" timezone={@timezone} last_updated_uts={@last_updated_uts} />
        </div>
      </div>

      <div class="flow-root">
        <div class="mt-5 flex justify-between items-center">
          <h1 class="text-base lg:text-2xl text-zinc-900 dark:text-zinc-200 font-semibold">
            {gettext("Scrobble activity")}
          </h1>
          <.refresh_lastfm_feed_button />
        </div>
        <.tabs id="scrobble-activity" class="mt-4">
          <.tabs_list active_tab={@scrobble_activity_mode} variant="segmented" class="w-48">
            <:tab
              name="albums"
              phx-click={JS.push("set_scrobble_activity_mode", value: %{mode: "albums"})}
            >
              {gettext("Albums")}
            </:tab>
            <:tab
              name="tracks"
              phx-click={JS.push("set_scrobble_activity_mode", value: %{mode: "tracks"})}
            >
              {gettext("Tracks")}
            </:tab>
          </.tabs_list>

          <.tabs_panel name="albums" active={@scrobble_activity_mode == "albums"}>
            <ul
              id="scrobble-activity-albums"
              role="list"
              class="mt-5 p-6 bg-white dark:bg-zinc-800 rounded-md shadow-sm"
              phx-update="stream"
            >
              <li
                :for={
                  {id,
                   %{
                     album: album,
                     artist_id: artist_id,
                     collected_record_id: collected_record_id,
                     wishlisted_record_id: wishlisted_record_id,
                     cover_hash: cover_hash
                   }} <- @streams.recent_albums
                }
                id={id}
                class="group"
              >
                <div class="relative pb-4 group-last:pb-0">
                  <span
                    class="group-last:hidden absolute left-6 top-6 -ml-px h-full w-0.5 bg-zinc-200"
                    aria-hidden="true"
                  >
                  </span>
                  <div class="relative flex space-x-3 items-center justify-between">
                    <div class="flex min-w-0 justify-between space-x-4 items-center">
                      <img
                        class="h-12 w-12 rounded-md shadow-sm"
                        src={track_or_album_cover_url(album, cover_hash)}
                        alt={album.metadata.title}
                      />
                      <div>
                        <p
                          :if={!artist_id(album, artist_id)}
                          class="font-semibold text-sm block text-zinc-500 dark:text-zinc-400"
                        >
                          {album.artist.name}
                        </p>
                        <.link
                          :if={artist_id(album, artist_id)}
                          class="font-semibold text-sm block text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300"
                          navigate={~p"/artists/#{artist_id(album, artist_id)}"}
                        >
                          {album.artist.name}
                        </.link>
                        <p class="font-semibold text-sm md:text-base text-zinc-700 dark:text-zinc-300">
                          {album.metadata.title}
                        </p>
                        <time
                          datetime={format_scrobbled_at_uts(album.scrobbled_at_uts)}
                          class="whitespace-nowrap text-right text-xs sm:text-sm text-zinc-500 dark:text-zinc-400"
                        >
                          {album.scrobbled_at_label}
                        </time>
                        <.album_metadata_tooltip album={album} />
                      </div>
                    </div>

                    <.record_status_badges
                      musicbrainz_id={album.metadata.musicbrainz_id}
                      collected_record_id={collected_record_id}
                      wishlisted_record_id={wishlisted_record_id}
                    />

                    <.import_format_dropdown
                      :if={
                        album.metadata.musicbrainz_id !== "" and !collected_record_id and
                          !wishlisted_record_id
                      }
                      id={"actions-#{album.scrobbled_at_uts}-albums"}
                      musicbrainz_id={album.metadata.musicbrainz_id}
                    />
                  </div>
                </div>
              </li>
            </ul>
          </.tabs_panel>
          <.tabs_panel name="tracks" active={@scrobble_activity_mode == "tracks"}>
            <ul
              id="scrobble-activity-tracks"
              role="list"
              class="mt-5 p-6 bg-white dark:bg-zinc-800 rounded-md shadow-sm"
              phx-update="stream"
            >
              <li
                :for={
                  {id,
                   %{
                     track: track,
                     artist_id: artist_id,
                     collected_record_id: collected_record_id,
                     wishlisted_record_id: wishlisted_record_id,
                     cover_hash: cover_hash
                   }} <- @streams.recent_tracks
                }
                id={id}
                class="group"
              >
                <div class="relative pb-4 group-last:pb-0">
                  <span
                    class="group-last:hidden absolute left-6 top-6 -ml-px h-full w-0.5 bg-zinc-200"
                    aria-hidden="true"
                  >
                  </span>
                  <div class="relative flex space-x-3 items-center justify-between">
                    <div class="flex min-w-0 justify-between space-x-4 items-center">
                      <img
                        class="h-12 w-12 rounded-md shadow-sm"
                        src={track_or_album_cover_url(track, cover_hash)}
                        alt={track.title}
                      />
                      <div>
                        <p
                          :if={!artist_id(track, artist_id)}
                          class="font-semibold text-sm block text-zinc-500 dark:text-zinc-400"
                        >
                          {track.artist.name}
                        </p>
                        <.link
                          :if={artist_id(track, artist_id)}
                          class="font-semibold text-sm block text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300"
                          navigate={~p"/artists/#{artist_id(track, artist_id)}"}
                        >
                          {track.artist.name}
                        </.link>
                        <p class="font-semibold text-sm md:text-base text-zinc-700 dark:text-zinc-300">
                          {track.title}
                        </p>
                        <p class="font-semibold text-sm text-zinc-500 dark:text-zinc-400">
                          {track.album.title}
                        </p>
                        <time
                          datetime={format_scrobbled_at_uts(track.scrobbled_at_uts)}
                          class="whitespace-nowrap text-right text-xs sm:text-sm text-zinc-500 dark:text-zinc-400"
                        >
                          {track.scrobbled_at_label}
                        </time>
                        <.track_metadata_tooltip track={track} />
                      </div>
                    </div>

                    <.record_status_badges
                      musicbrainz_id={track.album.musicbrainz_id}
                      collected_record_id={collected_record_id}
                      wishlisted_record_id={wishlisted_record_id}
                    />

                    <.import_format_dropdown
                      :if={
                        track.album.musicbrainz_id !== "" and !collected_record_id and
                          !wishlisted_record_id
                      }
                      id={"actions-#{track.scrobbled_at_uts}-tracks"}
                      musicbrainz_id={track.album.musicbrainz_id}
                    />
                  </div>
                </div>
              </li>
            </ul>
          </.tabs_panel>
        </.tabs>
      </div>

      <div class="mt-5 grid grid-cols-1 lg:grid-cols-11 gap-4">
        <div class="lg:col-span-3">
          <div class="flex justify-between items-center">
            <h1 class="text-base lg:text-2xl text-zinc-900 dark:text-zinc-200 font-semibold">
              {gettext("On This day")}
            </h1>
            <.form
              :let={f}
              for={to_form(%{"current_date" => @current_date})}
              phx-change="set_current_date"
            >
              <.date_picker size="xs" field={f[:current_date]}>
                <:outer_suffix>
                  <.button
                    size="xs"
                    type="button"
                    phx-click={
                      JS.push("set_current_date", value: %{"current_date" => Date.utc_today()})
                    }
                  >
                    Today
                  </.button>
                </:outer_suffix>
              </.date_picker>
            </.form>
          </div>
          <div class="bg-white dark:bg-zinc-800 rounded-md shadow-sm">
            <.records_on_this_day
              current_date={@current_date}
              records={@records_on_this_day}
              record_show_path={fn record -> ~p"/collection/#{record}" end}
            />
          </div>
        </div>
        <div class="lg:col-span-4">
          <h1 class="text-base lg:text-2xl text-zinc-900 dark:text-zinc-200 font-semibold">
            {gettext("Top %{n} Collection Artists", %{n: length(@records_by_artist)})}
          </h1>
          <div class="mt-5 bg-white dark:bg-zinc-800 rounded-md shadow-sm">
            <.vertical_bar_chart
              data={@records_by_artist}
              width={600}
              height={26 * length(@records_by_artist)}
              color_class="fill-red-500"
              label_fn={fn datum -> datum.name end}
              value_fn={fn datum -> datum.count end}
              datum_click={
                fn datum ->
                  JS.navigate(~p"/artists/#{datum.id}")
                end
              }
              class="w-full"
            />
          </div>
        </div>

        <div class="lg:col-span-4">
          <h1 class="text-base lg:text-2xl text-zinc-900 dark:text-zinc-200 font-semibold">
            {gettext("Top %{n} Collection Genres", %{n: length(@records_by_genre)})}
          </h1>
          <div class="mt-5 bg-white dark:bg-zinc-800 rounded-md shadow-sm">
            <.vertical_bar_chart
              data={@records_by_genre}
              width={600}
              height={26 * length(@records_by_genre)}
              color_class="fill-zinc-500"
              label_fn={fn {genre, _count} -> genre end}
              value_fn={fn {_genre, count} -> count end}
              datum_click={
                fn {genre, _count} ->
                  JS.navigate(~p"/collection?#{%{query: ~s(genre:"#{genre}")}}")
                end
              }
              class="w-full"
            />
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_date = DateTime.now!(socket.assigns.timezone) |> DateTime.to_date()
    latest_record = Collection.get_latest_record()
    records_by_artists = Collection.count_records_by_artist(limit: 20)
    records_by_genre = Collection.count_records_by_genre(limit: 20)
    records_on_this_day = Collection.get_records_on_this_day(current_date)

    if connected?(socket) do
      LastFm.subscribe_to_feed()
    end

    {:ok,
     socket
     |> stream_configure(:recent_tracks,
       dom_id: fn %{track: track} -> "track-#{track.scrobbled_at_uts}" end
     )
     |> stream_configure(:recent_albums,
       dom_id: fn %{album: album} -> "album-#{album.scrobbled_at_uts}" end
     )
     |> assign_counts()
     |> assign_scrobble_activity()
     |> assign(
       current_date: current_date,
       scrobble_activity_mode: "albums",
       latest_record: latest_record,
       page_title: gettext("Stats"),
       current_section: :stats,
       records_by_artist: records_by_artists,
       records_by_genre: records_by_genre,
       records_on_this_day: records_on_this_day
     )}
  end

  @impl true
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
         |> assign(%{current_date: date, records_on_this_day: records_on_this_day})}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{track_count: 0}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{track_count: _count}, socket) do
    {:noreply,
     socket
     |> assign_scrobble_activity()}
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

  defp assign_scrobble_activity(socket) do
    %{
      recent_tracks: recent_tracks,
      recent_albums: recent_albums
    } = ScrobbleActivity.recent_activity(socket.assigns.timezone)

    scrobble_count = ScrobbleActivity.scrobble_count()

    last_updated_uts =
      if rt = List.first(recent_tracks) do
        rt.track.scrobbled_at_uts
      end

    socket
    |> assign(:last_updated_uts, last_updated_uts)
    |> assign(:scrobble_count, scrobble_count)
    |> stream(:recent_tracks, recent_tracks, reset: true)
    |> stream(:recent_albums, recent_albums, reset: true)
  end

  defp format_scrobbled_at_uts(uts) do
    uts
    |> DateTime.from_unix!()
    |> DateTime.to_iso8601()
  end

  defp track_or_album_cover_url(track_or_album, nil) do
    track_or_album.cover_url
  end

  defp track_or_album_cover_url(_track_or_album, cover_hash) do
    ~p"/assets/#{Transform.new(hash: cover_hash, width: 96)}"
  end

  defp artist_id(track_or_album, record_artist_id) do
    record_artist_id || track_or_album.artist.musicbrainz_id
  end
end
