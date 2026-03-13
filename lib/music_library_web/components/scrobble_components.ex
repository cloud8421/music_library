defmodule MusicLibraryWeb.ScrobbleComponents do
  @moduledoc """
  Universal search modal and related components.
  """

  alias LastFm.Track
  alias MusicLibrary.Records

  use MusicLibraryWeb, :html

  import MusicLibraryWeb.RecordComponents, only: [format_label: 1]

  def refresh_lastfm_feed_button(assigns) do
    ~H"""
    <button
      type="button"
      class="text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-300"
      phx-click="refresh_lastfm_feed"
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
              <.copy_to_clipboard
                :if={@track.musicbrainz_id not in ["", nil]}
                target_id={"tooltip-track-#{@track.scrobbled_at_uts}"}
                label={gettext("Copy track MusicBrainz ID to clipboard")}
              />
            </dd>
          </div>
          <div class="flex gap-2 w-full mt-2">
            <dt>{gettext("Album ID:")}</dt>
            <dd class="font-mono">
              <code id={"tooltip-track-album-#{@track.scrobbled_at_uts}"}>
                {@track.album.musicbrainz_id || gettext("Unknown")}
              </code>
              <.copy_to_clipboard
                :if={@track.album.musicbrainz_id not in ["", nil]}
                target_id={"tooltip-track-album-#{@track.scrobbled_at_uts}"}
                label={gettext("Copy album MusicBrainz ID to clipboard")}
              />
            </dd>
          </div>
          <div class="flex gap-2 w-full mt-2">
            <dt>{gettext("Artist ID:")}</dt>
            <dd class="font-mono">
              <code id={"tooltip-track-artist-#{@track.scrobbled_at_uts}"}>
                {@track.artist.musicbrainz_id || gettext("Unknown")}
              </code>
              <.copy_to_clipboard
                :if={@track.artist.musicbrainz_id not in ["", nil]}
                target_id={"tooltip-track-artist-#{@track.scrobbled_at_uts}"}
                label={gettext("Copy artist MusicBrainz ID to clipboard")}
              />
            </dd>
          </div>
        </dl>
      </:content>
    </.tooltip>
    """
  end

  attr :album, :map, required: true

  def album_metadata_tooltip(assigns) do
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
            <dt>{gettext("Album ID:")}</dt>
            <dd class="font-mono">
              <code id={"tooltip-album-#{@album.scrobbled_at_uts}"}>
                {@album.metadata.musicbrainz_id || gettext("Unknown")}
              </code>
              <.copy_to_clipboard
                :if={@album.metadata.musicbrainz_id not in ["", nil]}
                target_id={"tooltip-album-#{@album.scrobbled_at_uts}"}
                label={gettext("Copy album MusicBrainz ID to clipboard")}
              />
            </dd>
          </div>
          <div class="flex gap-2 w-full mt-2">
            <dt>{gettext("Artist ID:")}</dt>
            <dd class="font-mono">
              <code id={"tooltip-artist-#{@album.scrobbled_at_uts}"}>
                {@album.artist.musicbrainz_id || gettext("Unknown")}
              </code>
              <.copy_to_clipboard
                :if={@album.artist.musicbrainz_id not in ["", nil]}
                target_id={"tooltip-artist-#{@album.scrobbled_at_uts}"}
                label={gettext("Copy artist MusicBrainz ID to clipboard")}
              />
            </dd>
          </div>
        </dl>
      </:content>
    </.tooltip>
    """
  end

  attr :musicbrainz_id, :string, required: true
  attr :collected_record_id, :string, default: nil
  attr :wishlisted_record_id, :string, default: nil

  def record_status_badges(assigns) do
    ~H"""
    <div class="flex gap-1 flex-col text-right">
      <.badge :if={@musicbrainz_id == ""}>
        {gettext("No MB ID")}
      </.badge>
      <.link :if={@collected_record_id} navigate={~p"/collection/#{@collected_record_id}"}>
        <.badge color="success">{gettext("Collected")}</.badge>
      </.link>
      <.link :if={@wishlisted_record_id} navigate={~p"/wishlist/#{@wishlisted_record_id}"}>
        <.badge color="warning">{gettext("Wishlisted")}</.badge>
      </.link>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :musicbrainz_id, :string, required: true

  def import_format_dropdown(assigns) do
    ~H"""
    <.dropdown id={@id} placement="bottom-end">
      <:toggle>
        <.button variant="ghost">
          <span class="sr-only">{gettext("Choose which format to import")}</span>
          <.icon
            name="hero-star"
            class="h-5 w-5 text-zinc-500 dark:text-zinc-400 cursor-pointer"
            aria-hidden="true"
            data-slot="icon"
          />
        </.button>
      </:toggle>
      <.focus_wrap id={@id <> "-focus-wrap"}>
        <.dropdown_link
          :for={format <- Records.Record.formats()}
          id={@id <> "-#{format}-import"}
          phx-click={
            JS.push("import",
              value: %{id: @musicbrainz_id, format: format},
              page_loading: true
            )
          }
        >
          {format_label(format)}
        </.dropdown_link>
      </.focus_wrap>
    </.dropdown>
    """
  end
end
