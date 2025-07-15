defmodule MusicLibraryWeb.StatsComponents do
  use MusicLibraryWeb, :live_component

  attr :record, MusicLibrary.Records.Record, required: true
  attr :title, :string, required: true
  attr :class, :string

  def album_preview(assigns) do
    ~H"""
    <div
      class={[
        "relative overflow-hidden rounded-md bg-white dark:bg-zinc-800 px-4 pb-5 pt-5 shadow-sm sm:px-6 sm:pt-6 cursor-pointer",
        @class
      ]}
      phx-click={JS.navigate(~p"/collection/#{@record}")}
    >
      <dt>
        <img
          class="absolute w-20 rounded-md shadow-sm"
          src={~p"/covers/#{@record.id}?vsn=#{@record.cover_hash}"}
          alt={@record.title}
        />
        <p class="ml-24 truncate text-xs sm:text-sm font-medium text-zinc-500 dark:text-zinc-400">
          {@title}
        </p>
      </dt>
      <dd class="ml-24 mt-2 flex items-baseline pb-4 sm:pb-6">
        <p class="font-semibold">
          <span class="text-sm md:text-base lg:text-2xl block text-zinc-900 dark:text-zinc-300">
            {@record.title}
          </span>
          <.link
            :for={artist <- @record.artists}
            class="text-sm md:text-base text-zinc-600 dark:text-zinc-200 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200"
            navigate={~p"/artists/#{artist.musicbrainz_id}"}
          >
            {artist.name}
          </.link>
        </p>
      </dd>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :path, :string, required: true

  def counter(assigns) do
    ~H"""
    <div class="overflow-hidden rounded-md bg-white dark:bg-zinc-800 px-4 pb-3 pt-5 shadow-sm sm:px-6 sm:pt-6">
      <dt class="sm:mt-3">
        <p class="truncate text-sm font-medium text-center text-zinc-500 dark:text-zinc-400">
          {@title}
        </p>
      </dt>
      <dd class="mt-1">
        <.link
          navigate={@path}
          class="block text-2xl sm:text-3xl font-semibold text-center text-zinc-900 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200"
        >
          {@count}
        </.link>
      </dd>
    </div>
    """
  end

  attr :albums, :list, required: true
  attr :collected_releases, :list, required: true
  attr :wishlisted_releases, :list, required: true

  def top_albums_by_period(assigns) do
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

  attr :artists, :list, required: true

  def top_artists_by_period(assigns) do
    ~H"""
    <div class="mt-4">
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
            src={~p"/artists/#{artist.artist_musicbrainz_id}/image"}
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

  def refresh_lastfm_feed_button(assigns) do
    ~H"""
    <button
      type="button"
      class="phx-click-loading:animate-spin text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-300"
      phx-click={JS.push("refresh_lastfm_feed")}
    >
      <span class="sr-only">{gettext("Refresh LastFm Feed")}</span>
      <.icon name="hero-arrow-path" class="-mt-1 h-5 w-5" aria-hidden="true" data-slot="icon" />
    </button>
    """
  end

  def tracked_record?(tracked_releases, release_id) do
    Enum.find_value(tracked_releases, fn tracked_release ->
      if tracked_release.release_id == release_id, do: tracked_release.record_id
    end)
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
