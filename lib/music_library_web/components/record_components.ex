defmodule MusicLibraryWeb.RecordComponents do
  use MusicLibraryWeb, :html

  alias MusicBrainz.ReleaseSearchResult
  alias MusicLibrary.Records
  alias Phoenix.LiveView.JS

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
              <.link
                :for={artist <- record.artists}
                class="text-zinc-700 hover:text-zinc-500 dark:text-zinc-400 dark:hover:text-zinc-300"
                navigate={~p"/artists/#{artist.musicbrainz_id}"}
              >
                {artist.name}
              </.link>
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
              <.icon name="hero-banknotes" class="-mt-1 h-4 w-4" aria-hidden="true" data-slot="icon" />
              {Records.Record.format_as_date(record.purchased_at)}
            </p>
          </div>
          <%!-- TODO: replace with OSS version --%>
          <div class="relative flex-none">
            <button
              type="button"
              class="text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-300"
              aria-expanded="false"
              aria-haspopup="true"
              phx-click={toggle_actions_menu(record.id)}
              phx-click-away={close_actions_menu(record.id)}
            >
              <span class="sr-only">{gettext("Open options")}</span>
              <.icon
                name="hero-ellipsis-vertical"
                class="-mt-1 h-5 w-5"
                aria-hidden="true"
                data-slot="icon"
              />
            </button>
            <!--
              Dropdown menu, show/hide based on menu state.

              Entering: "transition ease-out duration-100"
                From: "transform opacity-0 scale-95"
                To: "transform opacity-100 scale-100"
              Leaving: "transition ease-in duration-75"
                From: "transform opacity-100 scale-100"
                To: "transform opacity-0 scale-95"
            -->
            <.focus_wrap
              id={"actions-#{record.id}"}
              class={[
                "hidden pointer-events-auto absolute right-0 z-10 mt-2 w-48 origin-top-right rounded-md bg-white dark:bg-zinc-800 py-2 shadow-lg ring-1 ring-zinc-900/5 focus:outline-hidden"
              ]}
              role="menu"
              aria-orientation="vertical"
              aria-labelledby="options-menu-0-button"
            >
              <.link
                class="block px-3 py-1 text-sm leading-6 text-zinc-900 dark:text-zinc-400 hover:bg-zinc-50 dark:hover:text-zinc-300 dark:hover:bg-zinc-700"
                role="menuitem"
                tabindex="0"
                id={"actions-#{record.id}-show"}
                navigate={@record_show_path.(record)}
              >
                {gettext("Show")}
              </.link>
              <a
                href={MusicBrainz.ReleaseGroup.url(record.musicbrainz_id)}
                target=".blank"
                class="block px-3 py-1 text-sm leading-6 text-zinc-900 dark:text-zinc-400 hover:bg-zinc-50 dark:hover:text-zinc-300 dark:hover:bg-zinc-700"
                role="menuitem"
                tabindex="0"
                id={"actions-#{record.id}-musicbrainz"}
              >
                {gettext("View on MusicBrainz")}
              </a>

              <.link
                class="block px-3 py-1 text-sm leading-6 text-zinc-900 dark:text-zinc-400 hover:bg-zinc-50 dark:hover:text-zinc-300 dark:hover:bg-zinc-700"
                role="menuitem"
                tabindex="0"
                id={"actions-#{record.id}-edit"}
                patch={@record_edit_path.(record)}
              >
                {gettext("Edit")}
              </.link>

              <.link
                :if={!record.purchased_at}
                class="block px-3 py-1 text-sm leading-6 text-zinc-900 dark:text-zinc-400 hover:bg-zinc-50 dark:hover:text-zinc-300 dark:hover:bg-zinc-700"
                role="menuitem"
                tabindex="0"
                id={"actions-#{record.id}-purchase"}
                phx-click={
                  JS.dispatch("music_library:confetti")
                  |> JS.push("add-to-collection", value: %{id: record.id})
                }
              >
                {gettext("Purchased")}
              </.link>

              <.link
                class="block px-3 py-1 text-sm leading-6 text-red-900 hover:bg-red-50 dark:text-red-700 dark:hover:bg-red-900/30 dark:hover:text-red-600"
                role="menuitem"
                tabindex="0"
                id={"actions-#{record.id}-delete"}
                phx-click={JS.push("delete", value: %{id: record.id}) |> hide("##{id}")}
                data-confirm={gettext("Are you sure?")}
              >
                {gettext("Delete")}
              </.link>
            </.focus_wrap>
          </div>
        </div>
      </li>
    </ul>
    """
  end

  attr :query, :string, required: true

  def search_form(assigns) do
    ~H"""
    <form class="w-full sm:w-1/3" for={@query} phx-submit="search" phx-change="search">
      <.input
        type="search"
        size="sm"
        id={:query}
        name={:query}
        value={@query}
        placeholder={gettext("Search")}
        phx-debounce="500"
        autocomplete="off"
      />
    </form>
    """
  end

  attr :records, :list, required: true
  attr :records_count, :integer, required: true
  attr :title, :string, required: true
  attr :id, :string, required: true
  attr :record_path, :any, required: true

  def record_grid(assigns) do
    ~H"""
    <div class="mt-4">
      <header class="flex items-baseline justify-start">
        <h2 class="font-semibold text-base sm:text-lg leading-5 text-zinc-700 dark:text-zinc-300">
          {@title}
        </h2>
        <span class="ml-2 text-xs font-normal text-zinc-700 dark:text-zinc-300">
          {ngettext("1 record", "%{count} records", @records_count)}
        </span>
      </header>
      <%!-- TODO: replace with OSS version --%>
      <ul
        id={@id}
        phx-update="stream"
        role="list"
        class="mt-4 grid grid-cols-3 gap-x-4 gap-y-8 sm:grid-cols-4 sm:gap-x-6 xl:gap-x-8"
      >
        <li :for={{id, record} <- @records} id={id} class="relative">
          <div class="group overflow-hidden rounded-lg bg-zinc-100 focus-within:ring-2 focus-within:ring-zinc-500 focus-within:ring-offset-2 focus-within:ring-offset-zinc-100">
            <div class="relative">
              <img
                alt={record.title}
                src={~p"/covers/#{record.id}?vsn=#{record.cover_hash}"}
                class="pointer-events-none aspect-square object-cover group-hover:opacity-75"
              />
              <span
                :if={Records.Record.included_release_groups_count(record) > 0}
                class={[
                  "absolute right-0 bottom-0 rounded-br-lg rounded-tl-lg px-2",
                  "text-sm font-medium",
                  "bg-zinc-50 dark:bg-zinc-500/10",
                  "text-zinc-700 dark:text-zinc-400",
                  "border-1 border-zinc-600/20 dark:border-zinc-500/20"
                ]}
              >
                {Records.Record.included_release_groups_count(record)}
              </span>
            </div>
            <button
              type="button"
              class="absolute inset-0 focus:outline-hidden"
              phx-click={JS.navigate(@record_path.(record))}
            >
              <span class="sr-only">{gettext("View details")}</span>
            </button>
          </div>
          <p class="pointer-events-none mt-2 block truncate text-sm font-medium text-zinc-900 dark:text-zinc-300">
            {record.title}
          </p>
          <p class="pointer-events-none block text-sm font-medium text-zinc-500">
            {format_label(record.format)} · {type_label(record.type)}
          </p>
          <p class="pointer-events-none block text-sm font-medium text-zinc-500">
            {Records.Record.format_release_date(record.release_date)}
          </p>
        </li>
      </ul>
    </div>
    """
  end

  def format_label(:cd), do: gettext("CD")
  def format_label(:backup), do: gettext("Backup")
  def format_label(:vinyl), do: gettext("Vinyl")
  def format_label(:blu_ray), do: gettext("Blu-ray")
  def format_label(:dvd), do: gettext("DVD")
  def format_label(:multi), do: gettext("Multi")

  def type_label(:album), do: gettext("Album")
  def type_label(:ep), do: gettext("EP")
  def type_label(:live), do: gettext("Live")
  def type_label(:compilation), do: gettext("Comp")
  def type_label(:single), do: gettext("Single")
  def type_label(:other), do: gettext("Other")

  def selected_release_label(record) do
    if release = Records.Record.selected_release(record) do
      release_label(release)
    else
      gettext("No release selected")
    end
  end

  def release_label(release) do
    [
      release.date,
      release.country |> country_label(),
      ReleaseSearchResult.format(release),
      release.disambiguation
    ]
    |> Enum.reject(fn fragment -> fragment in [nil, ""] end)
    |> Enum.join(" ")
  end

  defp country_label(nil), do: nil
  defp country_label("XW"), do: "🌍"
  defp country_label("XE"), do: "🇪🇺"

  defp country_label(country_code) do
    if flagmoji = Flagmojis.by_iso(country_code) do
      flagmoji.emoji
    else
      country_code
    end
  end

  def format_duration(milliseconds) do
    milliseconds
    |> System.convert_time_unit(:millisecond, :second)
    |> format_seconds()
  end

  defp format_seconds(seconds) when seconds <= 59 do
    "0:#{zero_pad(seconds)}"
  end

  defp format_seconds(seconds) do
    minutes = div(seconds, 60)
    remaining_seconds = rem(seconds, 60)

    format_minutes(minutes, remaining_seconds)
  end

  defp format_minutes(minutes, seconds) when minutes <= 59 do
    "#{minutes}:#{zero_pad(seconds)}"
  end

  defp format_minutes(minutes, seconds) do
    hours = div(minutes, 60)
    remaining_minutes = rem(minutes, 60)

    format_hours(hours, remaining_minutes, seconds)
  end

  defp format_hours(hours, minutes, seconds) do
    "#{hours}:#{zero_pad(minutes)}:#{zero_pad(seconds)}"
  end

  defp zero_pad(integer) do
    integer
    |> to_string()
    |> String.pad_leading(2, "0")
  end

  def toggle_actions_menu(record_id) do
    JS.toggle(to: "#actions-#{record_id}")
    |> JS.toggle_class("pointer-events-none", to: "#records > li")
  end

  def close_actions_menu(record_id) do
    JS.hide(to: "#actions-#{record_id}")
    |> JS.remove_class("pointer-events-none", to: "#records > li")
  end
end
