defmodule MusicLibraryWeb.ScrobbleComponents do
  @moduledoc """
  Universal search modal and related components.
  """

  alias LastFm.Track
  alias MusicLibrary.Records

  use MusicLibraryWeb, :html

  import MusicLibraryWeb.RecordComponents, only: [format_label: 1]

  def refresh_scrobbles_button(assigns) do
    ~H"""
    <button
      type="button"
      class="text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-300"
      phx-click="refresh_scrobbles"
    >
      <span class="sr-only">{gettext("Refresh scrobbles")}</span>
      <.icon
        name="hero-arrow-path"
        class="phx-click-loading:animate-spin size-5"
        aria-hidden="true"
        data-slot="icon"
      />
    </button>
    """
  end

  attr :track, Track, required: true

  def track_metadata_tooltip(assigns) do
    ~H"""
    <.tooltip class="bg-white text-zinc-900 shadow-lg ring-1 ring-zinc-200 dark:bg-zinc-800 dark:text-zinc-100 dark:ring-zinc-700">
      <.icon
        name="hero-information-circle"
        class="size-5 cursor-pointer text-zinc-500 dark:text-zinc-400"
        aria-hidden="true"
        data-slot="icon"
      />
      <:content>
        <dl class="divide-y divide-zinc-200 dark:divide-zinc-700">
          <.metadata_row
            label={gettext("Track ID")}
            value={@track.musicbrainz_id}
            id_prefix={"tooltip-track-#{@track.scrobbled_at_uts}"}
            copy_label={gettext("Copy track MusicBrainz ID to clipboard")}
          />
          <.metadata_row
            label={gettext("Album ID")}
            value={@track.album.musicbrainz_id}
            id_prefix={"tooltip-track-album-#{@track.scrobbled_at_uts}"}
            copy_label={gettext("Copy album MusicBrainz ID to clipboard")}
          />
          <.metadata_row
            label={gettext("Artist ID")}
            value={@track.artist.musicbrainz_id}
            id_prefix={"tooltip-track-artist-#{@track.scrobbled_at_uts}"}
            copy_label={gettext("Copy artist MusicBrainz ID to clipboard")}
          />
        </dl>
      </:content>
    </.tooltip>
    """
  end

  attr :album, :map, required: true

  def album_metadata_tooltip(assigns) do
    ~H"""
    <.tooltip class="bg-white text-zinc-900 shadow-lg ring-1 ring-zinc-200 dark:bg-zinc-800 dark:text-zinc-100 dark:ring-zinc-700">
      <.icon
        name="hero-information-circle"
        class="size-5 cursor-pointer text-zinc-500 dark:text-zinc-400"
        aria-hidden="true"
        data-slot="icon"
      />
      <:content>
        <dl class="divide-y divide-zinc-200 dark:divide-zinc-700">
          <.metadata_row
            label={gettext("Album ID")}
            value={@album.metadata.musicbrainz_id}
            id_prefix={"tooltip-album-#{@album.scrobbled_at_uts}"}
            copy_label={gettext("Copy album MusicBrainz ID to clipboard")}
          />
          <.metadata_row
            label={gettext("Artist ID")}
            value={@album.artist.musicbrainz_id}
            id_prefix={"tooltip-artist-#{@album.scrobbled_at_uts}"}
            copy_label={gettext("Copy artist MusicBrainz ID to clipboard")}
          />
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
    <div class="flex flex-col gap-1 text-right">
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
            class="icon cursor-pointer text-zinc-500 dark:text-zinc-400"
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

  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :id_prefix, :string, required: true
  attr :copy_label, :string, required: true

  defp metadata_row(assigns) do
    ~H"""
    <div class="px-3 py-2 first:pt-1.5 last:pb-1.5">
      <dt class="text-[0.65rem] font-medium tracking-wider text-zinc-400 uppercase dark:text-zinc-500">
        {@label}
      </dt>
      <dd class="mt-0.5 flex items-center justify-between gap-2">
        <code
          id={@id_prefix}
          class={[
            "truncate font-mono text-xs",
            if(@value not in ["", nil],
              do: "text-zinc-800 dark:text-zinc-200",
              else: "text-zinc-400 italic dark:text-zinc-500"
            )
          ]}
        >
          {@value || gettext("Unknown")}
        </code>
        <.copy_to_clipboard
          :if={@value not in ["", nil]}
          target_id={@id_prefix}
          label={@copy_label}
        />
      </dd>
    </div>
    """
  end
end
