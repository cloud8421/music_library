defmodule MusicLibraryWeb.StatsLive.TopArtists do
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
        {gettext("Top Artists")}
      </h1>
      <.tabs class="mt-4">
        <.tabs_list active_tab={name_from_period(@period)} variant="segmented" size="xs">
          <:tab
            class="flex-1"
            name="top_artists_last_30_days"
            phx-click={JS.push("set_period", value: %{period: "last_30_days"})}
            phx-target={@myself}
          >
            {gettext("30 days")}
          </:tab>
          <:tab
            class="flex-1"
            name="top_artists_last_90_days"
            phx-click={JS.push("set_period", value: %{period: "last_90_days"})}
            phx-target={@myself}
          >
            {gettext("90 days")}
          </:tab>
          <:tab
            class="flex-1"
            name="top_artists_last_365_days"
            phx-click={JS.push("set_period", value: %{period: "last_365_days"})}
            phx-target={@myself}
          >
            {gettext("Last year")}
          </:tab>
          <:tab
            class="flex-1"
            name="top_artists_all_time"
            phx-click={JS.push("set_period", value: %{period: "all_time"})}
            phx-target={@myself}
          >
            {gettext("All time")}
          </:tab>
        </.tabs_list>
        <.async_result :let={top_artists} assign={@top_artists}>
          <:loading>
            <div class="h-182 flex items-center justify-center">
              <.loading />
            </div>
          </:loading>
          <.top_artists_by_period artists={top_artists} />
        </.async_result>
      </.tabs>
    </div>
    """
  end

  defp name_from_period(period), do: "top_artists_#{period}"

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
     |> assign_top_artists()}
  end

  @impl true
  def handle_event("set_period", %{"period" => period}, socket) do
    {:noreply,
     socket
     |> assign(:period, String.to_existing_atom(period))
     |> assign_top_artists()}
  end

  attr :artists, :list, required: true

  def top_artists_by_period(assigns) do
    ~H"""
    <div class="mt-4 p-4 bg-white dark:bg-zinc-800 rounded-md shadow-sm">
      <div class="space-y-2">
        <div
          :for={artist <- @artists}
          phx-click={
            artist.artist_musicbrainz_id != "" &&
              JS.navigate(~p"/artists/#{artist.artist_musicbrainz_id}")
          }
          class={[
            "flex items-center space-x-3 p-2",
            artist.artist_musicbrainz_id != "" &&
              "cursor-pointer hover:bg-zinc-50 dark:hover:bg-zinc-800"
          ]}
        >
          <img
            :if={artist.artist_musicbrainz_id != ""}
            class="w-12 h-12 rounded-md object-cover"
            src={artist_image_path(artist)}
            alt={artist.artist_name}
            onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
          />
          <div
            :if={artist.artist_musicbrainz_id == ""}
            class="w-12 h-12 rounded-md bg-zinc-200 dark:bg-zinc-700 flex items-center justify-center"
          >
            <.icon name="hero-user" class="w-6 h-6 text-zinc-400" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-zinc-900 dark:text-zinc-300 hover:text-zinc-700 dark:hover:text-zinc-400 truncate">
              {artist.artist_name}
            </p>
          </div>
          <.badge>
            {artist.play_count}
          </.badge>
        </div>
      </div>
    </div>
    """
  end

  defp artist_image_path(artist) do
    payload =
      %Transform{hash: artist.image_hash, width: 96}
      |> Transform.encode!()

    ~p"/assets/#{payload}"
  end

  defp assign_top_artists(socket) do
    %{timezone: timezone, period: period} = socket.assigns
    current_time = DateTime.utc_now()

    assign_async(
      socket,
      :top_artists,
      fn ->
        top_artists =
          ScrobbleActivity.get_top_artists_by_period(
            limit: 10,
            current_time: current_time,
            timezone: timezone,
            period: period
          )

        {:ok, %{top_artists: top_artists}}
      end,
      reset: true
    )
  end
end
