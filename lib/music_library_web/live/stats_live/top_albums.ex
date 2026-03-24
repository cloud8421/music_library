defmodule MusicLibraryWeb.StatsLive.TopAlbums do
  use MusicLibraryWeb, :html

  alias MusicLibrary.Assets.Transform
  alias MusicLibrary.ListeningStats
  alias MusicLibraryWeb.StatsLive.TopByPeriod

  attr :id, :string, required: true
  attr :timezone, :string, required: true
  attr :last_updated_uts, :any

  def live(assigns) do
    ~H"""
    <TopByPeriod.live
      id={@id}
      timezone={@timezone}
      last_updated_uts={@last_updated_uts}
      title={gettext("Top Albums")}
      key={:top_albums}
      fetch_fn={&ListeningStats.get_top_albums_by_period/1}
    >
      <:item :let={albums}>
        <div
          :for={album <- albums}
          phx-click={navigate_to_record(album)}
          class={[
            "flex items-center space-x-3 p-2",
            (album.collected_record_id || album.wishlisted_record_id) &&
              "cursor-pointer hover:bg-zinc-100 dark:hover:bg-zinc-700"
          ]}
        >
          <img
            class="size-12 rounded-md object-cover shadow-sm"
            src={cover_url(album)}
            alt={album.album_title}
          />
          <div class="min-w-0 flex-1">
            <.link
              class="truncate text-xs text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300"
              navigate={~p"/artists/#{album.artist_musicbrainz_id}"}
            >
              {album.artist_name}
            </.link>
            <p class="truncate text-sm font-medium text-zinc-900 dark:text-zinc-300">
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
      </:item>
    </TopByPeriod.live>
    """
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
    ~p"/assets/#{Transform.new(hash: album.cover_hash, width: 96)}"
  end
end
