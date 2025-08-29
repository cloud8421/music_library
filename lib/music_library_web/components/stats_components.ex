defmodule MusicLibraryWeb.StatsComponents do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1, artist_links: 1]

  alias MusicLibrary.Records

  attr :record, Records.Record, required: true
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

  attr :record_show_path, :any, required: true
  attr :records, :list, required: true
  attr :current_date, Date, required: false, default: nil

  def records_on_this_day(assigns) do
    ~H"""
    <ul
      class="mt-5"
      role="list"
      id="records"
      phx-update="stream"
    >
      <li
        :for={{id, record} <- @records}
        phx-click={JS.navigate(@record_show_path.(record))}
        class="flex justify-between gap-x-6 py-2 hover:bg-zinc-50 dark:hover:bg-zinc-800 px-2 -mx-2 md:px-4 md:-mx-4 cursor-pointer"
        id={id}
      >
        <div class="flex min-w-0 gap-x-4 items-center">
          <div class="relative w-12 flex-none">
            <img
              class="rounded-lg"
              alt={record.title}
              src={~p"/covers/#{record.id}?vsn=#{record.cover_hash}"}
            />
            <span
              :if={Records.Record.included_release_groups_count(record) > 0}
              class={[
                "absolute right-0 bottom-0 rounded-br-lg rounded-tl-lg px-1",
                "text-xs font-medium",
                "bg-zinc-200/80 dark:bg-zinc-500/70",
                "text-zinc-700 dark:text-zinc-200",
                "border-1 border-zinc-600/20 dark:border-zinc-500/20"
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
                  class="-mt-1 h-4 w-4"
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
                <.icon name="hero-star" class="-mt-1 h-4 w-4" aria-hidden="true" data-slot="icon" />
                {Records.Record.format_as_date(record.inserted_at)}
              </span>
            </p>
          </div>
        </div>
      </li>
    </ul>
    """
  end

  def tracked_record?(tracked_releases, release_id) do
    Enum.find_value(tracked_releases, fn tracked_release ->
      if tracked_release.release_id == release_id, do: tracked_release.record_id
    end)
  end
end
