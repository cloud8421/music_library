defmodule MusicLibraryWeb.ScrobbledTracksLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.Components.Pagination
  import MusicLibraryWeb.LiveHelpers.Params
  import MusicLibraryWeb.ScrobbleComponents

  alias LastFm.Track
  alias MusicLibrary.Assets.Transform
  alias MusicLibrary.ScrobbleActivity

  @default_tracks_list_params %{
    query: "",
    page: 1,
    page_size: 20,
    order: :scrobbled_at
  }

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <div>
        <header class="gap-6">
          <div class="mb-2 mt-2">
            <.search_form query={@track_list_params.query} />
          </div>
        </header>

        <div class="flex items-end gap-6 mt-8 justify-between">
          <.button_group>
            <.button
              patch={order_path(@track_list_params, :scrobbled_at)}
              size="xs"
              class={[
                @track_list_params.order == :scrobbled_at && "bg-zinc-100! dark:bg-zinc-700!"
              ]}
            >
              <.icon
                name="hero-clock-solid"
                class="icon"
                aria-hidden="true"
                data-slot="icon"
              />
              {gettext("Scrobbled")}
            </.button>
            <.button
              patch={order_path(@track_list_params, :title)}
              size="xs"
              class={[
                @track_list_params.order == :title && "bg-zinc-100! dark:bg-zinc-700!"
              ]}
            >
              <.icon name="hero-musical-note-solid" class="icon" aria-hidden="true" data-slot="icon" />
              {gettext("Title")}
            </.button>
            <.button
              patch={order_path(@track_list_params, :artist)}
              size="xs"
              class={[
                @track_list_params.order == :artist && "bg-zinc-100! dark:bg-zinc-700!"
              ]}
            >
              <.icon name="hero-user-solid" class="icon" aria-hidden="true" data-slot="icon" />
              {gettext("Artist")}
            </.button>
            <.button
              patch={order_path(@track_list_params, :album)}
              size="xs"
              class={[
                @track_list_params.order == :album && "bg-zinc-100! dark:bg-zinc-700!"
              ]}
            >
              <.icon name="hero-musical-note-solid" class="icon" aria-hidden="true" data-slot="icon" />
              {gettext("Album")}
            </.button>
          </.button_group>
          <.refresh_lastfm_feed_button />
        </div>
      </div>

      <div class="mt-6">
        <ul
          class="divide-y divide-zinc-100 dark:divide-zinc-300/20 mt-5"
          role="list"
          id="tracks"
          phx-update="stream"
        >
          <li
            id="no-scrobbled-tracks"
            class="hidden only:block p-8 text-center bg-zinc-50 dark:bg-zinc-800 rounded-lg"
          >
            <.icon name="hero-musical-note" class="h-12 w-12 text-zinc-400 mx-auto mb-4" />
            <p class="text-zinc-600 dark:text-zinc-400">
              {gettext("No scrobbled tracks found")}
            </p>
          </li>

          <li
            :for={
              {id,
               %{
                 track: track,
                 artist_id: artist_id,
                 collected_record_id: collected_record_id,
                 wishlisted_record_id: wishlisted_record_id,
                 cover_hash: cover_hash
               }} <- @streams.tracks
            }
            id={id}
            class="flex justify-between gap-x-6 py-5 hover:bg-zinc-50 dark:hover:bg-zinc-800 px-2 -mx-2 md:px-4 md:-mx-4 cursor-pointer"
          >
            <div class="flex items-center space-x-4 flex-1 min-w-0">
              <div class="shrink-0">
                <img
                  class="h-12 w-12 rounded-md shadow-sm"
                  src={track_cover_url(track, cover_hash)}
                  alt={track.title}
                  onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
                />
              </div>

              <div class="min-w-0 flex-1">
                <p class="text-sm font-medium text-zinc-900 dark:text-zinc-100 truncate">
                  {track.title}
                </p>
                <p class="text-sm text-zinc-600 dark:text-zinc-400 truncate">
                  {track.artist.name}
                </p>
                <p class="text-sm text-zinc-500 dark:text-zinc-500 truncate">
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

            <div class="flex items-center">
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
              <.dropdown id={"actions-#{track.scrobbled_at_uts}"} placement="bottom-end">
                <:toggle>
                  <.button variant="ghost">
                    <span class="sr-only">{gettext("Actions")}</span>
                    <.icon
                      name="hero-ellipsis-vertical"
                      class="h-5 w-5 text-zinc-500 dark:text-zinc-400 cursor-pointer"
                      aria-hidden="true"
                      data-slot="icon"
                    />
                  </.button>
                </:toggle>
                <.dropdown_link patch={~p"/scrobbled-tracks/#{track.scrobbled_at_uts}/edit"}>
                  {gettext("Edit")}
                </.dropdown_link>
                <.dropdown_button
                  phx-click={
                    JS.push("delete", value: %{"scrobbled-at-uts": track.scrobbled_at_uts})
                    |> JS.hide(to: "##{id}")
                  }
                  data-confirm={gettext("Are you sure?")}
                  class={[
                    "text-red-900! hover:bg-red-50! dark:text-red-500! dark:hover:bg-red-900/30! dark:hover:text-red-600!"
                  ]}
                >
                  {gettext("Delete")}
                </.dropdown_button>
              </.dropdown>
            </div>
          </li>
        </ul>

        <.pagination id={:bottom_pagination} pagination_params={@track_list_params} />
      </div>

      <.structured_modal
        :if={@live_action == :edit}
        id="track-modal"
        on_close={JS.patch(back_path(@track_list_params))}
      >
        <.live_component
          module={MusicLibraryWeb.ScrobbledTracksLive.Form}
          id={@track.scrobbled_at_uts}
          action={@live_action}
          track={@track}
          patch={back_path(@track_list_params)}
        />
      </.structured_modal>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:current_section, :scrobble_activity)
      |> stream_configure(:tracks,
        dom_id: fn %{track: %Track{scrobbled_at_uts: id}} -> "tracks-#{id}" end
      )

    if connected?(socket) do
      LastFm.subscribe_to_feed()
    end

    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :edit, %{"scrobbled_at_uts" => id} = params) do
    track = ScrobbleActivity.get_track!(id)

    socket
    |> apply_fallback_index(params)
    |> assign(:page_title, gettext("Edit Track"))
    |> assign(:track, track)
    |> assign(:form, to_form(Track.changeset(track, %{})))
  end

  defp apply_action(socket, :index, params) do
    query = params["query"] || ""
    order = parse_order(params["order"] || "scrobbled_at")
    total_tracks = ScrobbleActivity.search_tracks_count(query)

    track_list_params =
      @default_tracks_list_params
      |> merge_query(query)
      |> merge_order(order)
      |> merge_pagination(params, total_tracks, allowed_page_sizes: [20, 50, 100, 200, 500])

    load_and_assign_tracks(socket, track_list_params)
  end

  def apply_fallback_index(socket, params) do
    if get_in(socket.assigns, [:streams, :tracks]) == nil do
      socket
      |> apply_action(:index, params)
    else
      socket
    end
  end

  @impl true
  def handle_info({MusicLibraryWeb.ScrobbledTracksLive.Form, {:saved, _track}}, socket) do
    {:noreply, load_and_assign_tracks(socket, socket.assigns.track_list_params)}
  end

  def handle_info(%{track_count: 0}, socket) do
    {:noreply, socket}
  end

  def handle_info(%{track_count: _count}, socket) do
    {:noreply, load_and_assign_tracks(socket, socket.assigns.track_list_params)}
  end

  @impl true
  def handle_event("delete", %{"scrobbled-at-uts" => scrobbled_at_uts}, socket) do
    track = ScrobbleActivity.get_track!(scrobbled_at_uts)
    {:ok, _} = ScrobbleActivity.delete_track(track)

    {:noreply, stream_delete(socket, :tracks, %{track: track})}
  end

  def handle_event("search", %{"query" => query}, socket) do
    qs =
      @default_tracks_list_params
      |> Map.put(:query, query)
      |> Map.take([:query, :page, :page_size])

    {:noreply, push_patch(socket, to: ~p"/scrobbled-tracks?#{qs}")}
  end

  def handle_event("refresh_lastfm_feed", _, socket) do
    LastFm.refresh_scrobbled_tracks()
    {:noreply, socket}
  end

  defp parse_order("scrobbled_at"), do: :scrobbled_at
  defp parse_order("title"), do: :title
  defp parse_order("artist"), do: :artist
  defp parse_order("album"), do: :album
  defp parse_order(_), do: :scrobbled_at

  defp load_and_assign_tracks(socket, track_list_params) do
    tracks = ScrobbleActivity.list_tracks(track_list_params)
    tracks_empty? = tracks == []

    socket
    |> assign(:track_list_params, track_list_params)
    |> assign(:tracks_empty?, tracks_empty?)
    |> assign(:page_title, gettext("Scrobbled Tracks"))
    |> stream(:tracks, tracks, reset: true)
  end

  def order_path(track_list_params, order) do
    qs =
      track_list_params
      |> Map.put(:order, order)
      |> Map.put(:page, 1)
      |> Map.take([:query, :page, :page_size, :order])

    ~p"/scrobbled-tracks?#{qs}"
  end

  def back_path(track_list_params) do
    qs =
      track_list_params
      |> Map.take([:query, :page, :page_size, :order])

    ~p"/scrobbled-tracks?#{qs}"
  end

  defp track_cover_url(track, nil) do
    track.cover_url
  end

  defp track_cover_url(_track, cover_hash) do
    ~p"/assets/#{Transform.new(hash: cover_hash, width: 96)}"
  end

  defp format_scrobbled_at_uts(uts) do
    uts
    |> DateTime.from_unix!()
    |> DateTime.to_iso8601()
  end
end
