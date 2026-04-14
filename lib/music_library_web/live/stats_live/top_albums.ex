defmodule MusicLibraryWeb.StatsLive.TopAlbums do
  use MusicLibraryWeb, :html

  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias MusicLibrary.Assets.Transform
  alias MusicLibrary.ListeningStats
  alias MusicLibrary.Records
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
            <span class={[
              "inline-flex items-center rounded-md px-2 py-0.5 text-xs font-medium cursor-pointer",
              play_count_badge_classes(status)
            ]}>
              {@album.play_count}
            </span>
          </:toggle>
          <.top_album_dropdown_link
            :for={record <- @album.matching_records}
            record={record}
          />
        </.dropdown>
    <% end %>
    """
  end

  attr :record, :map, required: true

  defp top_album_dropdown_link(assigns) do
    path =
      if assigns.record.purchased_at,
        do: ~p"/collection/#{assigns.record.id}",
        else: ~p"/wishlist/#{assigns.record.id}"

    assigns = assign(assigns, :path, path)

    ~H"""
    <.dropdown_link navigate={@path}>
      <span class="flex items-center gap-2">
        <.badge :if={@record.purchased_at} color="success" size="sm">
          {gettext("C")}
        </.badge>
        <.badge :if={!@record.purchased_at} color="warning" size="sm">
          {gettext("W")}
        </.badge>
        <span>
          {format_label(String.to_existing_atom(@record.format))} · {type_label(
            String.to_existing_atom(@record.type)
          )}
          <span :if={@record.purchased_at} class="text-zinc-500 dark:text-zinc-400">
            · {Records.Record.format_as_date(@record.purchased_at)}
          </span>
        </span>
      </span>
    </.dropdown_link>
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

  defp badge_status([]), do: nil

  defp badge_status(records) do
    all_collected = Enum.all?(records, & &1.purchased_at)
    all_wishlisted = Enum.all?(records, &is_nil(&1.purchased_at))

    cond do
      all_collected -> :collected
      all_wishlisted -> :wishlisted
      true -> :mixed
    end
  end

  defp play_count_badge_classes(:collected),
    do:
      "bg-emerald-50 text-emerald-700 ring-1 ring-emerald-600/20 dark:bg-emerald-400/10 dark:text-emerald-400 dark:ring-emerald-400/20"

  defp play_count_badge_classes(:wishlisted),
    do:
      "bg-yellow-50 text-yellow-800 ring-1 ring-yellow-600/20 dark:bg-yellow-400/10 dark:text-yellow-500 dark:ring-yellow-400/20"

  defp play_count_badge_classes(:mixed),
    do:
      "bg-yellow-50 text-emerald-700 ring-1 ring-emerald-600/40 dark:bg-yellow-400/10 dark:text-emerald-400 dark:ring-emerald-400/40"

  defp cover_url(album) when is_nil(album.cover_hash) do
    album.cover_url
  end

  defp cover_url(album) do
    ~p"/assets/#{Transform.new(hash: album.cover_hash, width: 96)}"
  end
end
