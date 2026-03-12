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
              "cursor-pointer hover:bg-zinc-50 dark:hover:bg-zinc-700"
          ]}
        >
          <.artist_image
            :if={artist.musicbrainz_id != ""}
            class="w-12 h-12 rounded-md shadow-sm object-cover"
            artist={artist}
            width={96}
            image_hash={artist.image_hash}
          />
          <div
            :if={artist.musicbrainz_id == ""}
            class="w-12 h-12 rounded-md bg-zinc-200 dark:bg-zinc-700 flex items-center justify-center"
          >
            <.icon name="hero-user" class="w-6 h-6 text-zinc-400" />
          </div>
          <div class="flex-1 min-w-0">
            <p class="text-sm font-medium text-zinc-900 dark:text-zinc-300 truncate">
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
