defmodule MusicLibraryWeb.ScrobbleComponents do
  @moduledoc """
  Universal search modal and related components.
  """

  alias LastFm.Track

  use MusicLibraryWeb, :html

  def refresh_lastfm_feed_button(assigns) do
    ~H"""
    <button
      type="button"
      class="text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-300"
      phx-click={JS.push("refresh_lastfm_feed")}
    >
      <span class="sr-only">{gettext("Refresh LastFm Feed")}</span>
      <.icon
        name="hero-arrow-path"
        class="phx-click-loading:animate-spin h-5 w-5"
        aria-hidden="true"
        data-slot="icon"
      />
    </button>
    """
  end

  attr :track, Track, required: true

  def track_metadata_tooltip(assigns) do
    ~H"""
    <.tooltip>
      <.icon
        name="hero-information-circle"
        class="h-5 w-5 text-zinc-500 dark:text-zinc-400 cursor-pointer"
        aria-hidden="true"
        data-slot="icon"
      />
      <:content>
        <dl class="p-2">
          <div class="flex gap-2 w-full">
            <dt>{gettext("Track ID:")}</dt>
            <dd class="font-mono">
              <code id={"tooltip-track-#{@track.scrobbled_at_uts}"}>
                {@track.musicbrainz_id || gettext("Unknown")}
              </code>
              <button
                :if={@track.musicbrainz_id not in ["", nil]}
                phx-click={
                  JS.dispatch("music_library:clipcopy",
                    to: "#tooltip-track-#{@track.scrobbled_at_uts}"
                  )
                  |> JS.transition("animate-shake")
                }
              >
                <span class="sr-only">
                  {gettext("Copy track MusicBrainz ID to clipboard")}
                </span>
                <.icon
                  name="hero-clipboard-document"
                  class="h-5 w-5"
                  aria-hidden="true"
                  data-slot="icon"
                />
              </button>
            </dd>
          </div>
          <div class="flex gap-2 w-full mt-2">
            <dt>{gettext("Album ID:")}</dt>
            <dd class="font-mono">
              <code id={"tooltip-track-album-#{@track.scrobbled_at_uts}"}>
                {@track.album.musicbrainz_id || gettext("Unknown")}
              </code>
              <button
                :if={@track.album.musicbrainz_id not in ["", nil]}
                phx-click={
                  JS.dispatch("music_library:clipcopy",
                    to: "#tooltip-track-album-#{@track.scrobbled_at_uts}"
                  )
                  |> JS.transition("animate-shake")
                }
              >
                <span class="sr-only">
                  {gettext("Copy album MusicBrainz ID to clipboard")}
                </span>
                <.icon
                  name="hero-clipboard-document"
                  class="h-5 w-5"
                  aria-hidden="true"
                  data-slot="icon"
                />
              </button>
            </dd>
          </div>
          <div class="flex gap-2 w-full mt-2">
            <dt>{gettext("Artist ID:")}</dt>
            <dd class="font-mono">
              <code id={"tooltip-track-artist-#{@track.scrobbled_at_uts}"}>
                {@track.artist.musicbrainz_id || gettext("Unknown")}
              </code>
              <button
                :if={@track.artist.musicbrainz_id not in ["", nil]}
                phx-click={
                  JS.dispatch("music_library:clipcopy",
                    to: "#tooltip-track-artist-#{@track.scrobbled_at_uts}"
                  )
                  |> JS.transition("animate-shake")
                }
              >
                <span class="sr-only">
                  {gettext("Copy artist MusicBrainz ID to clipboard")}
                </span>
                <.icon
                  name="hero-clipboard-document"
                  class="h-5 w-5"
                  aria-hidden="true"
                  data-slot="icon"
                />
              </button>
            </dd>
          </div>
        </dl>
      </:content>
    </.tooltip>
    """
  end
end
