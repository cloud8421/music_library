defmodule MusicLibraryWeb.StatsLive.TopAlbums do
  use MusicLibraryWeb, :html

  import MusicLibraryWeb.ScrobbleComponents,
    only: [record_dropdown_link: 1, badge_status: 1, badge_color: 1]

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
            navigable?(album) &&
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
          <.top_album_badge album={album} />
        </div>
      </:item>
    </TopByPeriod.live>
    """
  end

  attr :album, :map, required: true

  defp top_album_badge(assigns) do
    assigns =
      assigns
      |> assign(:status, badge_status(assigns.album.matching_records))
      |> assign(:count, length(assigns.album.matching_records))

    ~H"""
    <%= case {@count, @status} do %>
      <% {0, _} -> %>
        <.badge>{@album.play_count}</.badge>
      <% {1, :collected} -> %>
        <.badge color="success">{@album.play_count}</.badge>
      <% {1, :wishlisted} -> %>
        <.badge color="warning">{@album.play_count}</.badge>
      <% {_, status} -> %>
        <.dropdown
          id={"top-album-#{@album.album_musicbrainz_id}"}
          placement="bottom-end"
        >
          <:toggle>
            <.badge
              color={badge_color(status)}
              class={[
                "cursor-pointer",
                status == :mixed &&
                  "bg-linear-50 from-success/10 to-warning/30 dark:from-success/20 dark:to-warning/60 text-foreground-success-soft"
              ]}
            >
              {@album.play_count}
            </.badge>
          </:toggle>
          <.record_dropdown_link
            :for={record <- @album.matching_records}
            record={record}
          />
        </.dropdown>
    <% end %>
    """
  end

  defp navigate_to_record(%{matching_records: [record]}) do
    if record.purchased_at do
      JS.navigate(~p"/collection/#{record.id}")
    else
      JS.navigate(~p"/wishlist/#{record.id}")
    end
  end

  defp navigate_to_record(_album), do: nil

  defp navigable?(%{matching_records: [_]}), do: true
  defp navigable?(_), do: false

  defp cover_url(album) when is_nil(album.cover_hash) do
    album.cover_url
  end

  defp cover_url(album) do
    ~p"/assets/#{Transform.new(hash: album.cover_hash, width: 96)}"
  end
end
