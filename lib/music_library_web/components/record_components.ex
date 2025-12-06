defmodule MusicLibraryWeb.RecordComponents do
  use MusicLibraryWeb, :html

  alias MusicBrainz.ReleaseSearchResult
  alias MusicLibrary.Assets.Transform
  alias MusicLibrary.Records
  alias Phoenix.LiveView.JS

  attr :record, :map, required: true
  attr :class, :string, required: false, default: "rounded-lg"
  attr :width, :integer, default: nil

  def record_cover(assigns) do
    payload =
      Transform.new(hash: assigns.record.cover_hash, width: assigns.width)
      |> Transform.encode!()

    assigns = assign(assigns, :payload, payload)

    ~H"""
    <img
      class={@class}
      alt={@record.title}
      src={~p"/assets/#{@payload}"}
    />
    """
  end

  attr :artists, :list, required: true
  attr :joinphrase_class, :string, default: nil

  def artist_links(assigns) do
    ~H"""
    <span :for={artist <- @artists}>
      <.link
        class="text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300"
        navigate={~p"/artists/#{artist.musicbrainz_id}"}
      >
        {artist.name}
      </.link>
      <span class={[@joinphrase_class, "leading-5 text-zinc-400 dark:text-zinc-300"]}>
        {artist.joinphrase}
      </span>
    </span>
    """
  end

  attr :record_show_path, :any, required: true
  attr :record_edit_path, :any, required: true
  attr :records, :list, required: true
  attr :current_date, Date, required: false, default: nil

  def record_list(assigns) do
    ~H"""
    <ul
      class="divide-y divide-zinc-100 dark:divide-zinc-300/20 mt-5"
      role="list"
      id="records"
      phx-update="stream"
    >
      <li
        :for={{id, record} <- @records}
        phx-click={JS.navigate(@record_show_path.(record))}
        class="flex justify-between gap-x-6 py-5 hover:bg-zinc-50 dark:hover:bg-zinc-800 px-2 -mx-2 md:px-4 md:-mx-4 cursor-pointer"
        id={id}
      >
        <div class="flex min-w-0 gap-x-4 items-center">
          <div class="relative w-20 flex-none">
            <.record_cover record={record} width={160} />
            <span
              :if={Records.Record.included_release_groups_count(record) > 0}
              class={[
                "absolute right-0 bottom-0 rounded-br-lg rounded-tl-lg px-1",
                "text-xs font-medium",
                "bg-zinc-200/80 dark:bg-zinc-500/70",
                "text-zinc-700 dark:text-zinc-200",
                "border border-zinc-600/20 dark:border-zinc-500/20"
              ]}
            >
              {Records.Record.included_release_groups_count(record)}
            </span>
          </div>
          <div class="min-w-0 flex-auto">
            <h1 class="text-sm leading-6 text-zinc-700">
              <.artist_links joinphrase_class="text-xs" artists={record.artists} />
            </h1>
            <h2 class="mt-1 flex font-semibold text-sm sm:text-base leading-5 text-zinc-700 dark:text-zinc-300 text-wrap">
              {record.title}
            </h2>
            <p class="mt-1 text-xs leading-5 text-zinc-500 dark:text-zinc-400">
              {Records.Record.format_release_date(record.release_date)}
              <span :if={@current_date && !Records.Record.released?(record, @current_date)}>
                ({gettext("Unreleased")})
              </span>
            </p>
            <p class="sm:hidden mt-1 text-xs leading-5 text-zinc-500 dark:text-zinc-400">
              {format_label(record.format)} · {type_label(record.type)}
              <span :if={record.purchased_at}>
                ·
                <span class="sr-only">
                  {gettext("Purchased on")}
                </span>
                <.icon
                  name="hero-banknotes"
                  class="h-4 w-4"
                  aria-hidden="true"
                  data-slot="icon"
                />
                {Records.Record.format_as_date(record.purchased_at)}
              </span>
              <span :if={!record.purchased_at}>
                ·
                <span class="sr-only">
                  {gettext("Wishlisted on")}
                </span>
                <.icon name="hero-star" class="h-4 w-4" aria-hidden="true" data-slot="icon" />
                {Records.Record.format_as_date(record.inserted_at)}
              </span>
            </p>
          </div>
        </div>
        <div class="flex shrink-0 items-center gap-x-6">
          <div class="hidden sm:flex sm:flex-col sm:items-end">
            <p class="text-xs leading-6 text-zinc-900 dark:text-zinc-300">
              {format_label(record.format)} · {type_label(record.type)}
            </p>
            <p :if={record.purchased_at} class="text-xs leading-6 text-zinc-900 dark:text-zinc-300">
              <span class="sr-only">
                {gettext("Purchased on")}
              </span>
              <.icon name="hero-banknotes" class="h-4 w-4" aria-hidden="true" data-slot="icon" />
              {Records.Record.format_as_date(record.purchased_at)}
            </p>
            <p :if={!record.purchased_at} class="text-xs leading-6 text-zinc-900 dark:text-zinc-300">
              <span class="sr-only">
                {gettext("Wishlisted on")}
              </span>
              <.icon name="hero-star" class="h-4 w-4" aria-hidden="true" data-slot="icon" />
              {Records.Record.format_as_date(record.inserted_at)}
            </p>
          </div>
          <.dropdown id={"actions-#{record.id}"} placement="bottom-end">
            <:toggle>
              <.button
                variant="ghost"
                phx-click={JS.toggle_class("pointer-events-none", to: "#records > li")}
                phx-click-away={JS.remove_class("pointer-events-none", to: "#records > li")}
              >
                <span class="sr-only">{gettext("Actions")}</span>
                <.icon
                  name="hero-ellipsis-vertical"
                  class="h-5 w-5 text-zinc-500 dark:text-zinc-400 cursor-pointer"
                  aria-hidden="true"
                  data-slot="icon"
                />
              </.button>
            </:toggle>
            <.focus_wrap id={"actions-#{record.id}-focus-wrap"} class="pointer-events-auto">
              <.dropdown_link id={"actions-#{record.id}-edit"} patch={@record_edit_path.(record)}>
                {gettext("Edit")}
              </.dropdown_link>

              <.dropdown_link
                :if={!record.purchased_at}
                id={"actions-#{record.id}-purchase"}
                phx-click={
                  JS.dispatch("music_library:confetti")
                  |> JS.push("add-to-collection", value: %{id: record.id})
                }
              >
                {gettext("Purchased")}
              </.dropdown_link>
              <.dropdown_separator />
              <.dropdown_link
                id={"actions-#{record.id}-delete"}
                phx-click={JS.push("delete", value: %{id: record.id}) |> hide("##{id}")}
                data-confirm={gettext("Are you sure?")}
                class={[
                  "text-red-900! hover:bg-red-50! dark:text-red-500! dark:hover:bg-red-900/30! dark:hover:text-red-600!"
                ]}
              >
                {gettext("Delete")}
              </.dropdown_link>
            </.focus_wrap>
          </.dropdown>
        </div>
      </li>
    </ul>
    """
  end

  attr :records, :list, required: true
  attr :records_count, :integer, default: 0
  attr :title, :string, default: nil
  attr :id, :string, required: true
  attr :record_show_path, :any, required: true
  attr :record_edit_path, :any, required: true
  attr :display_artist_names, :boolean, default: false
  attr :density, :atom, values: [:low, :high], default: :low

  def record_grid(assigns) do
    ~H"""
    <div class="mt-4">
      <header
        :if={@title}
        class="flex items-baseline justify-start"
      >
        <h2 class="font-semibold text-base sm:text-lg leading-5 text-zinc-700 dark:text-zinc-300">
          {@title}
        </h2>
        <span class="ml-2 text-xs font-normal text-zinc-700 dark:text-zinc-300">
          {ngettext("1 record", "%{count} records", @records_count)}
        </span>
      </header>
      <ul
        id={@id}
        phx-update="stream"
        role="list"
        class={[
          @density == :low &&
            "mt-4 grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-4 sm:gap-x-6 xl:gap-x-8",
          @density == :high &&
            "mt-4 grid grid-cols-2 gap-x-4 gap-y-8 sm:grid-cols-4 md:grid-cols-6 xl:grid-cols-8"
        ]}
      >
        <li :for={{id, record} <- @records} id={id} class="relative">
          <div
            class="relative cursor-pointer"
            phx-click={JS.navigate(@record_show_path.(record))}
          >
            <.record_cover
              record={record}
              class="aspect-square object-cover rounded-lg hover:shadow-lg/20"
              width={460}
            />
            <span
              :if={Records.Record.included_release_groups_count(record) > 0}
              class={[
                "absolute right-0 bottom-0 rounded-br-lg rounded-tl-lg px-2",
                "text-sm font-medium",
                "bg-zinc-50 dark:bg-zinc-500/10",
                "text-zinc-700 dark:text-zinc-400",
                "border border-zinc-600/20 dark:border-zinc-500/20"
              ]}
            >
              {Records.Record.included_release_groups_count(record)}
            </span>
            <div class="absolute right-2 top-2 rounded-full bg-zinc-100/50 hover:bg-zinc-100/75 dark:bg-zinc-700/50 dark:hover:bg-zinc-700/75 size-5">
              <.dropdown id={"actions-#{record.id}"} placement="bottom-end">
                <:toggle>
                  <span class="sr-only">{gettext("Actions")}</span>
                  <.icon
                    name="hero-ellipsis-vertical"
                    class="size-5 text-zinc-800 dark:text-zinc-200 cursor-pointer"
                    aria-hidden="true"
                    data-slot="icon"
                    phx-click={JS.toggle_class("pointer-events-none", to: "#{@id} > li")}
                    phx-click-away={JS.remove_class("pointer-events-none", to: "#{@id} > li")}
                  />
                </:toggle>
                <.focus_wrap id={"actions-#{record.id}-focus-wrap"}>
                  <.dropdown_link
                    id={"actions-#{record.id}-edit"}
                    patch={@record_edit_path.(record)}
                  >
                    {gettext("Edit")}
                  </.dropdown_link>

                  <.dropdown_link
                    :if={!record.purchased_at}
                    id={"actions-#{record.id}-purchase"}
                    phx-click={
                      JS.dispatch("music_library:confetti")
                      |> JS.push("add-to-collection", value: %{id: record.id})
                    }
                  >
                    {gettext("Purchased")}
                  </.dropdown_link>
                  <.dropdown_separator />
                  <.dropdown_link
                    id={"actions-#{record.id}-delete"}
                    phx-click={JS.push("delete", value: %{id: record.id}) |> hide("##{id}")}
                    data-confirm={gettext("Are you sure?")}
                    class="text-red-900! hover:bg-red-50! dark:text-red-500! dark:hover:bg-red-900/30! dark:hover:text-red-600!"
                  >
                    {gettext("Delete")}
                  </.dropdown_link>
                </.focus_wrap>
              </.dropdown>
            </div>
          </div>
          <div class="mt-2">
            <h1
              :if={@display_artist_names}
              class="text-sm leading-6 text-zinc-700"
            >
              <.artist_links joinphrase_class="text-xs" artists={record.artists} />
            </h1>
            <p class="pointer-events-none text-sm font-medium text-zinc-900 dark:text-zinc-300">
              {record.title}
            </p>
          </div>
          <p class="pointer-events-none block text-sm font-medium text-zinc-500">
            {format_label(record.format)} · {type_label(record.type)}
          </p>
          <p class="pointer-events-none block text-sm font-medium text-zinc-500">
            <.icon
              name="hero-calendar-days"
              class="-mt-1 h-4 w-4"
              aria-hidden="true"
              data-slot="icon"
            />
            {Records.Record.format_release_date(record.release_date)}
            <p
              :if={record.purchased_at}
              class="pointer-events-none block text-sm font-medium text-zinc-500"
            >
              <.icon
                name="hero-banknotes"
                class="h-4 w-4"
                aria-hidden="true"
                data-slot="icon"
              />
              {Records.Record.format_as_date(record.purchased_at)}
            </p>
          </p>
        </li>
      </ul>
    </div>
    """
  end

  attr :release, :map, required: true
  attr :class, :string, required: false, default: nil

  def release_summary(assigns) do
    ~H"""
    <div class={[
      @class,
      "grid grid-cols-2 w-full auto-cols-min space-x-1 text-zinc-700 dark:text-zinc-300"
    ]}>
      <div class="space-x-1">
        <span :if={@release.catalog_number} class="font-mono text-xs md:text-sm">
          {@release.catalog_number}
        </span>
        <.format_badge release={@release} />
      </div>
      <div class="text-right">
        <span class="text-xs md:text-sm">{Records.Record.format_release_date(@release.date)}</span>
        <span>{country_label(@release.country)}</span>
      </div>
      <div class="col-span-2">
        <span class="text-xs text-zinc-900 dark:text-zinc-400">{@release.disambiguation}</span>
      </div>
    </div>
    """
  end

  attr :release, :map, required: true

  defp format_badge(assigns) do
    ~H"""
    <.badge class="text-xs md:text-sm">
      {@release |> ReleaseSearchResult.format() |> format_label()}
    </.badge>
    """
  end

  def format_label(:cd), do: gettext("CD")
  def format_label(:backup), do: gettext("Backup")
  def format_label(:vinyl), do: gettext("Vinyl")
  def format_label(:blu_ray), do: gettext("Blu-ray")
  def format_label(:dvd), do: gettext("DVD")
  def format_label(:multi), do: gettext("Multi")
  def format_label(:digital_download), do: gettext("Download")
  def format_label(:vhs), do: gettext("VHS")
  def format_label(:unknown), do: gettext("Unknown")

  def type_label(:album), do: gettext("Album")
  def type_label(:ep), do: gettext("EP")
  def type_label(:live), do: gettext("Live")
  def type_label(:compilation), do: gettext("Comp")
  def type_label(:single), do: gettext("Single")
  def type_label(:other), do: gettext("Other")

  def release_label(release) do
    [
      release.catalog_number,
      ReleaseSearchResult.format(release),
      Records.Record.format_release_date(release.date),
      country_label(release.country)
    ]
    |> Enum.reject(fn fragment -> fragment in [nil, ""] end)
    |> Enum.join(" ")
  end

  def country_label(nil), do: nil
  def country_label("XW"), do: "🌍"
  def country_label("XE"), do: "🇪🇺"

  def country_label(country_code) do
    if flagmoji = Flagmojis.by_iso(country_code) do
      flagmoji.emoji
    else
      country_code
    end
  end

  attr :record, Records.Record, required: true

  def record_colors(assigns) do
    ~H"""
    <span class="flex items-center">
      <span
        :for={color <- @record.dominant_colors}
        class="inline-block w-4 h-4 mr-1"
        style={"background-color: #{color}"}
      >
      </span>
    </span>
    """
  end

  attr :similar_records, :list, required: true
  attr :record_show_path, :any, required: true
  attr :section, :atom, required: true

  def similar_records(assigns) do
    ~H"""
    <div :if={@similar_records != []} class="mt-8 px-4">
      <header class="flex items-baseline justify-start">
        <h2 class="font-semibold text-base sm:text-lg leading-5 text-zinc-700 dark:text-zinc-300">
          {gettext("Similar Records")}
        </h2>
        <span class="ml-2 text-xs font-normal text-zinc-500 dark:text-zinc-400">
          {gettext("Based on genres, artists, and release year")}
        </span>
      </header>

      <ul
        role="list"
        class="mt-4 grid grid-cols-2 gap-x-4 gap-y-6 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-6 sm:gap-x-6"
      >
        <li
          :for={%{record: record, similarity: similarity} <- @similar_records}
          class="relative"
          phx-click={JS.navigate(@record_show_path.(record))}
        >
          <.record_cover
            record={record}
            class="aspect-square object-cover rounded-lg hover:shadow-lg/20"
            width={300}
          />
          <span class="absolute top-2 right-2 rounded-full px-2 py-0.5 text-xs font-medium bg-zinc-900/75 text-white backdrop-blur-sm">
            {Float.round(100 - similarity * 100, 0)}%
          </span>

          <p class="pointer-events-none mt-2 block truncate text-sm font-medium text-zinc-900 dark:text-zinc-300">
            {record.title}
          </p>
          <p class="pointer-events-none block truncate text-xs text-zinc-500 dark:text-zinc-400">
            {Records.Record.artist_names(record)}
          </p>
        </li>
      </ul>
    </div>
    """
  end

  attr :record, Records.Record, required: true

  def release_list(assigns) do
    ~H"""
    <.sheet
      id={"release-list-" <> @record.id}
      placement="right"
      class="min-w-xs sm:min-w-sm"
    >
      <h3 class="text-lg font-semibold text-zinc-700 dark:text-zinc-300">
        {gettext("Available releases")}
      </h3>
      <div class="mt-6 space-y-4">
        <.release_summary
          :for={release_id <- @record.release_ids}
          release={Records.Record.find_release(@record, release_id)}
          class={
            @record.selected_release_id == release_id && "bg-zinc-100 dark:bg-zinc-800 p-2 rounded-lg"
          }
        />
      </div>
    </.sheet>
    """
  end
end
