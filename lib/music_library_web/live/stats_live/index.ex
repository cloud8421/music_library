defmodule MusicLibraryWeb.StatsLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibrary.FormatNumber, only: [to_compact: 1]
  import MusicLibraryWeb.ChartComponents
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]
  import MusicLibraryWeb.StatsComponents
  import MusicLibraryWeb.ScrobbleComponents

  alias MusicLibrary.Assets.Transform
  alias MusicLibrary.{Collection, ListeningStats, Records, Wishlist}
  alias MusicLibraryWeb.ErrorMessages
  alias MusicLibraryWeb.StatsLive.{TopAlbums, TopArtists}
  alias Phoenix.LiveView.AsyncResult

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_section={@current_section}
      socket={@socket}
      toasts_sync={assigns[:toasts_sync]}
    >
      <.section>
        <:title>{gettext("Records")}</:title>
        <div class="mt-5 grid min-h-35 grid-cols-3 gap-5 sm:grid-cols-5">
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
            path={~p"/scrobbled-tracks"}
          />
        </div>
      </.section>

      <div :if={@collection_count > 0} class="grid gap-x-5 md:grid-cols-2">
        <.formats_stats collection_count_by_format={@collection_count_by_format} />
        <.types_stats collection_count_by_type={@collection_count_by_type} />
      </div>

      <div class="grid grid-cols-1 gap-x-5 md:grid-cols-2 lg:grid-cols-3">
        <TopArtists.live id="top-artists" timezone={@timezone} last_updated_uts={@last_updated_uts} />
        <TopAlbums.live id="top-albums" timezone={@timezone} last_updated_uts={@last_updated_uts} />
        <.async_result :let={records_on_this_day} assign={@on_this_day_records}>
          <:loading>
            <.section container_class="order-first lg:order-last">
              <:title>{gettext("On This day")}</:title>
              <div class="rounded-md bg-white p-6 shadow-sm dark:bg-zinc-800 animate-pulse">
                <div class="mb-2 h-4 w-2/3 rounded bg-zinc-200 dark:bg-zinc-700"></div>
                <div class="h-4 w-1/2 rounded bg-zinc-200 dark:bg-zinc-700"></div>
              </div>
            </.section>
          </:loading>
          <:failed :let={_reason}>
            <.section container_class="order-first lg:order-last">
              <:title>{gettext("On This day")}</:title>
              <div class="rounded-md bg-white p-6 shadow-sm dark:bg-zinc-800 text-sm text-zinc-400 dark:text-zinc-500">
                {gettext("Could not load records on this day.")}
              </div>
            </.section>
          </:failed>
          <.on_this_day
            current_date={@current_date}
            records_on_this_day={records_on_this_day}
          />
        </.async_result>
      </div>

      <div id="daily-scrobble-counts">
        <.section>
          <:title>{gettext("Daily Scrobbles")}</:title>
          <div class="mt-5 rounded-md bg-white shadow-sm dark:bg-zinc-800">
            <.vertical_bar_chart
              data={@daily_scrobble_counts}
              color_class="bg-red-500 dark:bg-red-400"
              label_fn={fn %{date: date, count: _count} -> Calendar.strftime(date, "%b %d") end}
              value_fn={fn %{date: _date, count: count} -> count end}
            />
          </div>
        </.section>
      </div>

      <.scrobble_activity
        scrobble_activity_mode={@scrobble_activity_mode}
        streams={@streams}
      />

      <.async_result :let={summary} assign={@collection_summary}>
        <:loading>
          <div class="grid grid-cols-1 gap-x-5 md:grid-cols-2 lg:grid-cols-3">
            <.section>
              <:title>{gettext("Loading…")}</:title>
              <div class="mt-5 rounded-md bg-white p-6 shadow-sm dark:bg-zinc-800 animate-pulse">
                <div class="mb-3 h-4 w-3/4 rounded bg-zinc-200 dark:bg-zinc-700"></div>
                <div class="h-4 w-1/2 rounded bg-zinc-200 dark:bg-zinc-700"></div>
              </div>
            </.section>
          </div>
        </:loading>
        <:failed :let={_reason}></:failed>
        <div
          :if={@collection_count > 0}
          class="grid grid-cols-1 gap-x-5 md:grid-cols-2 lg:grid-cols-3"
        >
          <.top_collection_artists records_by_artist={summary.records_by_artist} />
          <.top_collection_genres records_by_genre={summary.records_by_genre} />
          <.top_release_years records_by_release_year={summary.records_by_release_year} />
        </div>
      </.async_result>

      <.structured_modal
        :if={@rule_picker_album_title}
        id="rule-picker-modal"
        on_close={JS.push("close_rule_picker")}
      >
        <.live_component
          module={MusicLibraryWeb.ScrobbleRulePicker}
          id="rule-picker"
          album_title={@rule_picker_album_title}
        />
      </.structured_modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    current_date = DateTime.now!(socket.assigns.timezone) |> DateTime.to_date()
    timezone = socket.assigns.timezone

    if connected?(socket) do
      ListeningStats.subscribe()
    end

    {:ok,
     socket
     |> stream_configure(:recent_tracks,
       dom_id: fn %{track: track} -> "track-#{track.scrobbled_at_uts}" end
     )
     |> stream_configure(:recent_albums,
       dom_id: fn %{album: album} -> "album-#{album.scrobbled_at_uts}" end
     )
     |> stream(:recent_tracks, [])
     |> stream(:recent_albums, [])
     |> assign(
       daily_scrobble_counts: ListeningStats.daily_scrobble_counts(timezone: timezone),
       current_date: current_date,
       latest_record: Collection.get_latest_record(),
       collection_count: Collection.count(),
       wishlist_count: Wishlist.count(),
       scrobble_count: ListeningStats.scrobble_count(),
       collection_count_by_format: Collection.count_records_by_format(),
       collection_count_by_type: Collection.count_records_by_type(),
       last_updated_uts: nil,
       scrobble_activity_mode: "albums",
       page_title: gettext("Stats"),
       current_section: :stats,
       rule_picker_album_title: nil
     )
     |> assign_async(:collection_summary, fn ->
       {:ok,
        %{
          collection_summary: %{
            records_by_artist: Collection.count_records_by_artist(limit: 20),
            records_by_genre: Collection.count_records_by_genre(limit: 20),
            records_by_release_year: Collection.count_records_by_release_year(limit: 20)
          }
        }}
     end)
     |> assign_async(:on_this_day_records, fn ->
       {:ok,
        %{
          on_this_day_records:
            current_date
            |> Collection.get_records_on_this_day()
            |> Collection.group_records_by_release_group()
        }}
     end)
     |> start_async(:scrobble_activity, fn ->
       %{
         recent_tracks: recent_tracks,
         recent_albums: recent_albums
       } = ListeningStats.recent_activity(timezone)

       last_updated_uts =
         if rt = List.first(recent_tracks), do: rt.track.scrobbled_at_uts

       {:ok,
        %{
          recent_tracks: recent_tracks,
          recent_albums: recent_albums,
          last_updated_uts: last_updated_uts
        }}
     end)}
  end

  @impl true
  def handle_async(:scrobble_activity, {:ok, {:ok, result}}, socket) do
    %{recent_tracks: tracks, recent_albums: albums, last_updated_uts: uts} = result

    {:noreply,
     socket
     |> assign(:last_updated_uts, uts)
     |> stream(:recent_tracks, tracks, reset: true)
     |> stream(:recent_albums, albums, reset: true)}
  end

  def handle_async(:scrobble_activity, {:ok, {:error, reason}}, socket) do
    require Logger
    Logger.error("Failed to load scrobble activity: #{inspect(reason)}")

    {:noreply, socket}
  end

  def handle_async(:scrobble_activity, {:exit, reason}, socket) do
    require Logger
    Logger.error("Scrobble activity task exited: #{inspect(reason)}")

    {:noreply, socket}
  end

  @impl true
  def handle_event("refresh_scrobbles", _, socket) do
    ListeningStats.refresh()
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

      {:error, reason} ->
        {:noreply,
         socket
         |> put_toast(
           :error,
           gettext("Error wishlisting record") <> ": " <> ErrorMessages.friendly_message(reason)
         )}
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
        records_on_this_day =
          date
          |> Collection.get_records_on_this_day()
          |> Collection.group_records_by_release_group()

        {:noreply,
         socket
         |> assign(:current_date, date)
         |> assign(
           :on_this_day_records,
           AsyncResult.ok(
             socket.assigns.on_this_day_records,
             records_on_this_day
           )
         )}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end

  def handle_event("open_rule_picker", %{"album-title" => album_title}, socket) do
    {:noreply, assign(socket, :rule_picker_album_title, album_title)}
  end

  def handle_event("close_rule_picker", _, socket) do
    {:noreply, assign(socket, :rule_picker_album_title, nil)}
  end

  @impl true
  def handle_info({MusicLibraryWeb.ScrobbleRulePicker, {:rule_created, _rule}}, socket) do
    {:noreply,
     socket
     |> assign(:rule_picker_album_title, nil)
     |> assign_scrobble_activity()}
  end

  def handle_info(%{track_count: 0}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{track_count: _count}, socket) do
    {:noreply,
     socket
     |> assign_scrobble_activity()}
  end

  attr :records_by_release_year, :list, required: true

  defp top_release_years(assigns) do
    ~H"""
    <.section>
      <:title>{gettext("Top 20 Release Years")}</:title>
      <div class="mt-5 rounded-md bg-white shadow-sm dark:bg-zinc-800">
        <.horizontal_bar_chart
          data={@records_by_release_year}
          color_class="bg-zinc-800 dark:bg-zinc-300"
          label_fn={fn {year, _count} -> year end}
          value_fn={fn {_year, count} -> count end}
          datum_click={
            fn {year, _count} ->
              JS.navigate(~p"/collection?#{%{query: "release_year:#{year}"}}")
            end
          }
          class="w-full"
        />
      </div>
    </.section>
    """
  end

  attr :records_by_genre, :list, required: true

  defp top_collection_genres(assigns) do
    ~H"""
    <.section>
      <:title>{gettext("Top %{n} Collection Genres", %{n: length(@records_by_genre)})}</:title>
      <div class="mt-5 rounded-md bg-white shadow-sm dark:bg-zinc-800">
        <.horizontal_bar_chart
          data={@records_by_genre}
          color_class="bg-zinc-500"
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
    </.section>
    """
  end

  attr :records_by_artist, :list, required: true

  defp top_collection_artists(assigns) do
    ~H"""
    <.section>
      <:title>{gettext("Top %{n} Collection Artists", %{n: length(@records_by_artist)})}</:title>
      <div class="mt-5 rounded-md bg-white shadow-sm dark:bg-zinc-800">
        <.horizontal_bar_chart
          data={@records_by_artist}
          color_class="bg-red-500"
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
    </.section>
    """
  end

  attr :scrobble_activity_mode, :string, required: true
  attr :streams, :any, required: true

  defp scrobble_activity(assigns) do
    ~H"""
    <div class="flow-root">
      <.tabs id="scrobble-activity" class="mt-4">
        <.section>
          <:title>
            {gettext("Scrobble activity")}
            <.refresh_scrobbles_button />
          </:title>
          <:side_actions>
            <.tabs_list active_tab={@scrobble_activity_mode} variant="segmented" size="xs">
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
          </:side_actions>
          <.tabs_panel name="albums" active={@scrobble_activity_mode == "albums"}>
            <ul
              id="scrobble-activity-albums"
              role="list"
              class="mt-4 rounded-md bg-white p-6 shadow-sm dark:bg-zinc-800"
              phx-update="stream"
            >
              <li
                :for={
                  {id,
                   %{
                     album: album,
                     artist_id: artist_id,
                     matching_records: matching_records,
                     cover_hash: cover_hash
                   }} <- @streams.recent_albums
                }
                id={id}
                class="group"
              >
                <div class="relative pb-4 group-last:pb-0">
                  <span
                    class="absolute top-6 left-6 -ml-px h-full w-0.5 bg-zinc-200 group-last:hidden"
                    aria-hidden="true"
                  ></span>
                  <div class="relative flex items-center justify-between space-x-3">
                    <div class="flex min-w-0 items-center justify-between space-x-4">
                      <img
                        class="size-12 rounded-md object-cover shadow-sm"
                        src={track_or_album_cover_url(album, cover_hash)}
                        alt={album.metadata.title}
                        onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
                      />
                      <div>
                        <p
                          :if={!artist_id(album, artist_id)}
                          class="block text-sm font-semibold text-zinc-500 dark:text-zinc-400"
                        >
                          {album.artist.name}
                        </p>
                        <.link
                          :if={artist_id(album, artist_id)}
                          class="block text-sm font-semibold text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300"
                          navigate={~p"/artists/#{artist_id(album, artist_id)}"}
                        >
                          {album.artist.name}
                        </.link>
                        <p class="text-sm font-semibold text-zinc-700 md:text-base dark:text-zinc-300">
                          {album.metadata.title}
                        </p>
                        <time
                          datetime={format_scrobbled_at_uts(album.scrobbled_at_uts)}
                          class="text-right text-xs whitespace-nowrap text-zinc-500 sm:text-sm dark:text-zinc-400"
                        >
                          {album.scrobbled_at_label}
                        </time>
                        <.album_metadata_tooltip album={album} />
                      </div>
                    </div>

                    <.record_status_badges
                      id={"status-#{album.scrobbled_at_uts}-albums"}
                      musicbrainz_id={album.metadata.musicbrainz_id}
                      matching_records={matching_records}
                      album_title={album.metadata.title}
                    />

                    <.import_format_dropdown
                      :if={album.metadata.musicbrainz_id !== "" and matching_records == []}
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
              class="mt-4 rounded-md bg-white p-6 shadow-sm dark:bg-zinc-800"
              phx-update="stream"
            >
              <li
                :for={
                  {id,
                   %{
                     track: track,
                     artist_id: artist_id,
                     matching_records: matching_records,
                     cover_hash: cover_hash
                   }} <- @streams.recent_tracks
                }
                id={id}
                class="group"
              >
                <div class="relative pb-4 group-last:pb-0">
                  <span
                    class="absolute top-6 left-6 -ml-px h-full w-0.5 bg-zinc-200 group-last:hidden"
                    aria-hidden="true"
                  ></span>
                  <div class="relative flex items-center justify-between space-x-3">
                    <div class="flex min-w-0 items-center justify-between space-x-4">
                      <img
                        class="size-12 rounded-md object-cover shadow-sm"
                        src={track_or_album_cover_url(track, cover_hash)}
                        alt={track.title}
                        onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
                      />
                      <div>
                        <p
                          :if={!artist_id(track, artist_id)}
                          class="block text-sm font-semibold text-zinc-500 dark:text-zinc-400"
                        >
                          {track.artist.name}
                        </p>
                        <.link
                          :if={artist_id(track, artist_id)}
                          class="block text-sm font-semibold text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300"
                          navigate={~p"/artists/#{artist_id(track, artist_id)}"}
                        >
                          {track.artist.name}
                        </.link>
                        <p class="text-sm font-semibold text-zinc-700 md:text-base dark:text-zinc-300">
                          {track.title}
                        </p>
                        <p class="text-sm font-semibold text-zinc-500 dark:text-zinc-400">
                          {track.album.title}
                        </p>
                        <time
                          datetime={format_scrobbled_at_uts(track.scrobbled_at_uts)}
                          class="text-right text-xs whitespace-nowrap text-zinc-500 sm:text-sm dark:text-zinc-400"
                        >
                          {track.scrobbled_at_label}
                        </time>
                        <.track_metadata_tooltip track={track} />
                      </div>
                    </div>

                    <.record_status_badges
                      id={"status-#{track.scrobbled_at_uts}-tracks"}
                      musicbrainz_id={track.album.musicbrainz_id}
                      matching_records={matching_records}
                      album_title={track.album.title}
                    />

                    <.import_format_dropdown
                      :if={track.album.musicbrainz_id !== "" and matching_records == []}
                      id={"actions-#{track.scrobbled_at_uts}-tracks"}
                      musicbrainz_id={track.album.musicbrainz_id}
                    />
                  </div>
                </div>
              </li>
            </ul>
          </.tabs_panel>
        </.section>
      </.tabs>
    </div>
    """
  end

  attr :current_date, Date, required: true
  attr :records_on_this_day, :list, required: true

  defp on_this_day(assigns) do
    ~H"""
    <.section container_class="order-first lg:order-last">
      <:title>{gettext("On This day")}</:title>
      <:side_actions>
        <.form
          :let={f}
          id="on-this-day-form"
          for={to_form(%{"current_date" => @current_date})}
          phx-change="set_current_date"
        >
          <.date_picker size="xs" field={f[:current_date]}>
            <:outer_suffix>
              <.button
                size="xs"
                type="button"
                phx-click={JS.push("set_current_date", value: %{"current_date" => Date.utc_today()})}
              >
                {gettext("Today")}
              </.button>
            </:outer_suffix>
          </.date_picker>
        </.form>
      </:side_actions>
      <div class="rounded-md bg-white shadow-sm dark:bg-zinc-800">
        <.records_on_this_day
          current_date={@current_date}
          records={@records_on_this_day}
          record_show_path={fn record -> ~p"/collection/#{record}" end}
        />
      </div>
    </.section>
    """
  end

  attr :collection_count_by_type, :list, required: true

  defp types_stats(assigns) do
    ~H"""
    <.section>
      <:title>{gettext("Types")}</:title>
      <.counters_by_category
        categories_with_counts={@collection_count_by_type}
        category_format_fn={&type_label/1}
        category_path_fn={fn type -> ~p"/collection?query=type:#{type}" end}
      />
    </.section>
    """
  end

  attr :collection_count_by_format, :list, required: true

  defp formats_stats(assigns) do
    ~H"""
    <.section>
      <:title>{gettext("Formats")}</:title>
      <.counters_by_category
        categories_with_counts={@collection_count_by_format}
        category_format_fn={&format_label/1}
        category_path_fn={fn format -> ~p"/collection?query=format:#{format}" end}
      />
    </.section>
    """
  end

  defp assign_scrobble_activity(socket) do
    timezone = socket.assigns.timezone

    %{
      recent_tracks: recent_tracks,
      recent_albums: recent_albums
    } = ListeningStats.recent_activity(timezone)

    scrobble_count = ListeningStats.scrobble_count()
    daily_scrobble_counts = ListeningStats.daily_scrobble_counts(timezone: timezone)

    last_updated_uts =
      if rt = List.first(recent_tracks) do
        rt.track.scrobbled_at_uts
      end

    socket
    |> assign(:last_updated_uts, last_updated_uts)
    |> assign(:scrobble_count, scrobble_count)
    |> assign(:daily_scrobble_counts, daily_scrobble_counts)
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
