defmodule MusicLibraryWeb.ScrobbleComponents do
  @moduledoc """
  Scrobble activity display components: status badges, import dropdowns,
  metadata tooltips, and record-matching UI.
  """

  alias LastFm.Track
  alias MusicLibrary.Records

  use MusicLibraryWeb, :html

  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  def refresh_scrobbles_button(assigns) do
    ~H"""
    <button
      type="button"
      class="text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-300"
      phx-click="refresh_scrobbles"
    >
      <span class="sr-only">{gettext("Refresh scrobbles")}</span>
      <.icon
        name="hero-cloud-arrow-down"
        class="phx-click-loading:animate-bounce size-5"
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

  attr :id, :string, required: true
  attr :musicbrainz_id, :string, required: true
  attr :matching_records, :list, default: []
  attr :album_title, :string, default: nil

  def record_status_badges(assigns) do
    assigns =
      assigns
      |> assign(:record_count, length(assigns.matching_records))
      |> assign(:status, badge_status(assigns.matching_records))

    ~H"""
    <div class="flex flex-col gap-1 text-right">
      <.badge :if={@musicbrainz_id == "" and is_nil(@album_title)}>
        {gettext("No MB ID")}
      </.badge>
      <.badge
        :if={@musicbrainz_id == "" and @album_title}
        class="cursor-pointer"
        phx-click="open_rule_picker"
        phx-value-album-title={@album_title}
      >
        <.icon name="hero-link" class="icon" />
        {gettext("No MB ID")}
      </.badge>

      <%= case {@record_count, @status} do %>
        <% {0, _} -> %>
        <% {1, :collected} -> %>
          <.link navigate={~p"/collection/#{hd(@matching_records).id}"}>
            <.badge color="success">{gettext("Collected")}</.badge>
          </.link>
        <% {1, :wishlisted} -> %>
          <.link navigate={~p"/wishlist/#{hd(@matching_records).id}"}>
            <.badge color="warning">{gettext("Wishlisted")}</.badge>
          </.link>
        <% {_, status} -> %>
          <.dropdown id={@id} placement="bottom-end">
            <:toggle>
              <.record_group_badge status={status} count={@record_count} />
            </:toggle>
            <.record_dropdown_link
              :for={record <- @matching_records}
              record={record}
            />
          </.dropdown>
      <% end %>
    </div>
    """
  end

  attr :status, :atom, required: true, values: [:collected, :wishlisted, :mixed]
  attr :count, :integer, required: true

  defp record_group_badge(assigns) do
    ~H"""
    <.badge
      color={badge_color(@status)}
      class={[
        "cursor-pointer",
        @status == :mixed &&
          "bg-linear-50 from-success/10 to-warning/30 dark:from-success/20 dark:to-warning/60 text-foreground-success-soft"
      ]}
    >
      {ngettext("1 record", "%{count} records", @count)}
    </.badge>
    """
  end

  attr :record, :map, required: true

  def record_dropdown_link(assigns) do
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
          {format_label(@record.format)} · {type_label(@record.type)}
          <span :if={@record.purchased_at} class="text-zinc-500 dark:text-zinc-400">
            · {Records.Record.format_as_date(@record.purchased_at)}
          </span>
        </span>
      </span>
    </.dropdown_link>
    """
  end

  def badge_status([]), do: nil

  def badge_status(records) do
    all_collected = Enum.all?(records, & &1.purchased_at)
    all_wishlisted = Enum.all?(records, &is_nil(&1.purchased_at))

    cond do
      all_collected -> :collected
      all_wishlisted -> :wishlisted
      true -> :mixed
    end
  end

  def badge_color(:collected), do: "success"
  def badge_color(:wishlisted), do: "warning"
  def badge_color(:mixed), do: "success"

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
