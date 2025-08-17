defmodule MusicLibraryWeb.StatsLive.TopAlbums do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.StatsComponents, only: [tracked_record?: 2]

  alias MusicLibrary.ScrobbleActivity

  def live(assigns) do
    ~H"""
    <.live_component module={__MODULE__} {assigns} id={@id} />
    """
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <h1 class="text-base lg:text-2xl text-zinc-900 dark:text-zinc-200 font-semibold">
        {gettext("Top Albums")}
      </h1>
      <.tabs class="mt-4">
        <.tabs_list active_tab={name_from_period(@period)} variant="segmented">
          <:tab
            class="flex-1"
            name="top_albums_last_30_days"
            phx-click={JS.push("set_period", value: %{period: "last_30_days"})}
            phx-target={@myself}
          >
            {gettext("Last 30 days")}
          </:tab>
          <:tab
            class="flex-1"
            name="top_albums_last_90_days"
            phx-click={JS.push("set_period", value: %{period: "last_90_days"})}
            phx-target={@myself}
          >
            {gettext("Last 90 days")}
          </:tab>
          <:tab
            class="flex-1"
            name="top_albums_last_365_days"
            phx-click={JS.push("set_period", value: %{period: "last_365_days"})}
            phx-target={@myself}
          >
            {gettext("Last year")}
          </:tab>
          <:tab
            class="flex-1"
            name="top_albums_all_time"
            phx-click={JS.push("set_period", value: %{period: "all_time"})}
            phx-target={@myself}
          >
            {gettext("All time")}
          </:tab>
        </.tabs_list>
        <.async_result :let={top_albums} assign={@top_albums}>
          <:loading>
            <div class="h-182 flex items-center justify-center">
              <.loading />
            </div>
          </:loading>
          <.top_albums_by_period
            albums={top_albums.albums}
            collected_releases={top_albums.collected_releases}
            wishlisted_releases={top_albums.wishlisted_releases}
          />
        </.async_result>
      </.tabs>
    </div>
    """
  end

  defp name_from_period(period), do: "top_albums_#{period}"

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:period, :last_30_days)}
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_top_albums()}
  end

  @impl true
  def handle_event("set_period", %{"period" => period}, socket) do
    {:noreply,
     socket
     |> assign(:period, String.to_existing_atom(period))
     |> assign_top_albums()}
  end

  attr :albums, :list, required: true
  attr :collected_releases, :list, required: true
  attr :wishlisted_releases, :list, required: true

  defp top_albums_by_period(assigns) do
    ~H"""
    <div class="mt-4">
      <div class="space-y-2">
        <div
          :for={album <- @albums}
          phx-click={
            navigate_to_record(@collected_releases, @wishlisted_releases, album.album_musicbrainz_id)
          }
          class={[
            "flex items-center space-x-3 p-2",
            tracked_record?(@collected_releases ++ @wishlisted_releases, album.album_musicbrainz_id) &&
              "cursor-pointer hover:bg-zinc-50 dark:hover:bg-zinc-800"
          ]}
        >
          <img
            class="w-12 h-12 rounded-md object-cover"
            src={album.cover_url}
            alt={album.album_title}
          />
          <div class="flex-1 min-w-0">
            <.link
              class="text-xs text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300 truncate"
              navigate={~p"/artists/#{album.artist_musicbrainz_id}"}
            >
              {album.artist_name}
            </.link>
            <p class="text-sm font-medium text-zinc-900 dark:text-zinc-300 truncate">
              {album.album_title}
            </p>
          </div>
          <.badge :if={album.album_musicbrainz_id == ""}>
            {album.play_count}
          </.badge>
          <.badge :if={
            album.album_musicbrainz_id !== "" and
              !tracked_record?(
                @collected_releases ++ @wishlisted_releases,
                album.album_musicbrainz_id
              )
          }>
            {album.play_count}
          </.badge>
          <.badge :if={tracked_record?(@collected_releases, album.album_musicbrainz_id)} color="green">
            {album.play_count}
          </.badge>
          <.badge
            :if={tracked_record?(@wishlisted_releases, album.album_musicbrainz_id)}
            color="yellow"
          >
            {album.play_count}
          </.badge>
        </div>
      </div>
    </div>
    """
  end

  defp assign_top_albums(socket) do
    %{timezone: timezone, period: period} = socket.assigns
    current_time = DateTime.utc_now()

    assign_async(
      socket,
      :top_albums,
      fn ->
        top_albums =
          ScrobbleActivity.get_top_albums_by_period(
            limit: 10,
            current_time: current_time,
            timezone: timezone,
            period: period
          )

        {:ok, %{top_albums: top_albums}}
      end,
      reset: true
    )
  end

  defp navigate_to_record(collected_releases, wishlisted_releases, musicbrainz_id) do
    cond do
      record_id = tracked_record?(collected_releases, musicbrainz_id) ->
        JS.navigate(~p"/collection/#{record_id}")

      record_id = tracked_record?(wishlisted_releases, musicbrainz_id) ->
        JS.navigate(~p"/wishlist/#{record_id}")

      true ->
        nil
    end
  end
end
