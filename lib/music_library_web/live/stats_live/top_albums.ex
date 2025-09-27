defmodule MusicLibraryWeb.StatsLive.TopAlbums do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Assets.Transform
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
        <.tabs_list active_tab={name_from_period(@period)} variant="segmented" size="xs">
          <:tab
            class="flex-1"
            name="top_albums_last_7_days"
            phx-click={JS.push("set_period", value: %{period: "last_7_days"})}
            phx-target={@myself}
          >
            {gettext("7d")}
          </:tab>
          <:tab
            class="flex-1"
            name="top_albums_last_30_days"
            phx-click={JS.push("set_period", value: %{period: "last_30_days"})}
            phx-target={@myself}
          >
            {gettext("30d")}
          </:tab>
          <:tab
            class="flex-1"
            name="top_albums_last_90_days"
            phx-click={JS.push("set_period", value: %{period: "last_90_days"})}
            phx-target={@myself}
          >
            {gettext("90d")}
          </:tab>
          <:tab
            class="flex-1"
            name="top_albums_last_365_days"
            phx-click={JS.push("set_period", value: %{period: "last_365_days"})}
            phx-target={@myself}
          >
            {gettext("1y")}
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
          <.top_albums_by_period albums={top_albums} />
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
     |> assign(:period, :last_7_days)}
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

  defp top_albums_by_period(assigns) do
    ~H"""
    <div class="mt-4 p-4 bg-white dark:bg-zinc-800 rounded-md shadow-sm">
      <div class="space-y-2">
        <div
          :for={album <- @albums}
          phx-click={navigate_to_record(album)}
          class={[
            "flex items-center space-x-3 p-2",
            (album.collected_record_id || album.wishlisted_record_id) &&
              "cursor-pointer hover:bg-zinc-50 dark:hover:bg-zinc-800"
          ]}
        >
          <img
            class="w-12 h-12 rounded-md object-cover"
            src={cover_url(album)}
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
            album.album_musicbrainz_id !== "" and !album.collected_record_id and
              !album.wishlisted_record_id
          }>
            {album.play_count}
          </.badge>
          <.badge
            :if={album.collected_record_id}
            color="success"
          >
            {album.play_count}
          </.badge>
          <.badge
            :if={album.wishlisted_record_id}
            color="warning"
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

  defp navigate_to_record(album) do
    cond do
      album.collected_record_id ->
        JS.navigate(~p"/collection/#{album.collected_record_id}")

      album.wishlisted_record_id ->
        JS.navigate(~p"/wishlist/#{album.wishlisted_record_id}")

      true ->
        nil
    end
  end

  defp cover_url(album) when is_nil(album.cover_hash) do
    album.cover_url
  end

  defp cover_url(album) do
    if LastFm.fallback_cover?(album.cover_url) do
      payload =
        Transform.new(hash: album.cover_hash, width: 96)
        |> Transform.encode!()

      ~p"/assets/#{payload}"
    else
      album.cover_url
    end
  end
end
