defmodule MusicLibraryWeb.StatsLive.TopArtists do
  use MusicLibraryWeb, :html

  import MusicLibraryWeb.RecordComponents, only: [artist_image: 1]

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
      title={gettext("Top Artists")}
      key={:top_artists}
      fetch_fn={&ListeningStats.get_top_artists_by_period/1}
    >
      <:item :let={artists}>
        <div
          :for={artist <- artists}
          phx-click={
            artist.musicbrainz_id != "" &&
              JS.navigate(~p"/artists/#{artist.musicbrainz_id}")
          }
          class={[
            "flex items-center space-x-3 p-2",
            artist.musicbrainz_id != "" &&
              "cursor-pointer hover:bg-zinc-100 dark:hover:bg-zinc-700"
          ]}
        >
          <.artist_image
            :if={artist.musicbrainz_id != ""}
            class="size-12 rounded-md object-cover shadow-sm"
            artist={artist}
            width={96}
            image_hash={artist.image_hash}
          />
          <div
            :if={artist.musicbrainz_id == ""}
            class="flex size-12 items-center justify-center rounded-md bg-zinc-200 dark:bg-zinc-700"
          >
            <.icon name="hero-user" class="size-6 text-zinc-400" />
          </div>
          <div class="min-w-0 flex-1">
            <p class="truncate text-sm font-medium text-zinc-900 dark:text-zinc-300">
              {artist.name}
            </p>
          </div>
          <.badge>
            {artist.play_count}
          </.badge>
        </div>
      </:item>
    </TopByPeriod.live>
    """
  end
end
