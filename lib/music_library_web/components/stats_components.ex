defmodule MusicLibraryWeb.StatsComponents do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.RecordComponents,
    only: [
      format_label: 1,
      type_label: 1,
      artist_links: 1,
      record_cover: 1,
      release_groups_badge: 1,
      release_status_tooltip: 1
    ]

  alias MusicLibrary.Records

  attr :record, Records.Record, required: false
  attr :title, :string, required: true
  attr :class, :string

  def album_preview(assigns) do
    ~H"""
    <div
      :if={@record}
      class={[
        "flex cursor-pointer items-center rounded-md bg-white px-4 py-5 shadow-sm sm:px-6 sm:pt-6 dark:bg-zinc-800",
        @class
      ]}
      phx-click={JS.navigate(~p"/collection/#{@record}")}
    >
      <div>
        <.record_cover
          record={@record}
          class="w-20 rounded-md shadow-sm md:w-24"
          width={192}
        />
      </div>
      <div class="ml-4">
        <p class="truncate text-xs font-medium text-zinc-500 sm:text-sm dark:text-zinc-400">
          {@title}
        </p>
        <p class="font-semibold">
          <span class="block text-sm text-zinc-900 md:text-base lg:text-2xl dark:text-zinc-300">
            {@record.title}
          </span>
          <.artist_links artists={@record.artists} joinphrase_class="text-sm md:text-base" />
        </p>
      </div>
    </div>
    <.link
      :if={!@record}
      navigate={~p"/collection/import"}
      class={[
        "flex items-center rounded-md bg-white px-4 py-5 shadow-sm sm:px-6 sm:pt-6 dark:bg-zinc-800",
        "border border-dashed border-zinc-300 dark:border-zinc-600",
        "group hover:border-zinc-400 dark:hover:border-zinc-500 transition-colors",
        @class
      ]}
    >
      <.icon
        name="hero-plus-circle"
        class="size-8 text-zinc-400 group-hover:text-zinc-500 dark:text-zinc-500 dark:group-hover:text-zinc-400"
      />
      <p class="ml-3 truncate text-xs font-medium text-zinc-500 group-hover:text-zinc-600 sm:text-sm dark:text-zinc-400 dark:group-hover:text-zinc-300">
        {gettext("Add a new record")}
      </p>
    </.link>
    """
  end

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :path, :string, required: false, default: nil
  attr :tooltip, :any, required: false, default: nil

  def counter(assigns) do
    ~H"""
    <div class="flex items-center justify-center overflow-hidden rounded-md bg-white shadow-sm dark:bg-zinc-800">
      <div class="p-4 md:p-0">
        <dt>
          <p class="truncate text-center text-sm font-medium text-zinc-500 dark:text-zinc-400">
            {@title}
          </p>
        </dt>
        <dd :if={!@tooltip} class="mt-1">
          <.link
            :if={@path}
            navigate={@path}
            class="block text-center text-2xl font-semibold text-zinc-900 hover:text-zinc-500 sm:text-3xl dark:text-zinc-300 dark:hover:text-zinc-200"
          >
            {@count}
          </.link>
          <p
            :if={!@path}
            class="block cursor-default text-center text-2xl font-semibold text-zinc-900 sm:text-3xl dark:text-zinc-300"
          >
            {@count}
          </p>
        </dd>
        <dd :if={@tooltip} class="mt-1">
          <.tooltip>
            <:content>
              <span id={"#{@title}-counter-tooltip"} phx-hook="FormatNumber">{@tooltip}</span>
            </:content>
            <.link
              :if={@path}
              navigate={@path}
              class="block text-center text-2xl font-semibold text-zinc-900 hover:text-zinc-500 sm:text-3xl dark:text-zinc-300 dark:hover:text-zinc-200"
            >
              {@count}
            </.link>
            <p
              :if={!@path}
              class="block cursor-default text-center text-2xl font-semibold text-zinc-900 sm:text-3xl dark:text-zinc-300"
            >
              {@count}
            </p>
          </.tooltip>
        </dd>
      </div>
    </div>
    """
  end

  attr :categories_with_counts, :list, required: true
  attr :category_format_fn, :any, required: true
  attr :category_path_fn, :any, required: true

  def counters_by_category(assigns) do
    ~H"""
    <dl class={[
      "mt-5 grid divide-x divide-zinc-200 overflow-hidden rounded-md bg-white shadow-sm dark:divide-zinc-900 dark:bg-zinc-800",
      stats_class(@categories_with_counts)
    ]}>
      <div :for={{category, count} <- @categories_with_counts} class="py-5">
        <dt class="text-center text-sm font-medium break-keep text-zinc-500 max-sm:text-xs dark:text-zinc-400">
          {@category_format_fn.(category)}
        </dt>
        <dd class="mt-1 text-center">
          <.link
            class="text-xl font-semibold hover:text-zinc-500 lg:text-2xl dark:text-zinc-300 dark:hover:text-zinc-200"
            navigate={@category_path_fn.(category)}
          >
            {count}
          </.link>
        </dd>
      </div>
    </dl>
    """
  end

  attr :record_show_path, :any, required: true
  attr :records, :list, required: true
  attr :current_date, Date, required: true

  def records_on_this_day(assigns) do
    ~H"""
    <ul
      class="mt-4 p-4"
      role="list"
      id="records-on-this-day"
    >
      <li
        id="no-records-on-this-day"
        class="hidden items-center justify-center py-8 text-sm text-zinc-500 only:flex dark:text-zinc-400"
      >
        {gettext("No records released on this day.")}
      </li>
      <%= for entry <- @records do %>
        <%= case entry do %>
          <% {:single, record} -> %>
            <.record_on_this_day_item
              record={record}
              current_date={@current_date}
              record_show_path={@record_show_path}
            />
          <% {:group, %{representative: rep, records: records}} -> %>
            <li id={"group-#{rep.musicbrainz_id}"} class="px-2">
              <details class="group/details">
                <summary class="-mx-2 flex cursor-pointer list-none justify-between gap-x-6 rounded-md px-2 py-1 hover:bg-zinc-100 dark:hover:bg-zinc-700 [&::-webkit-details-marker]:hidden">
                  <div class="flex min-w-0 items-center gap-x-4">
                    <div class="relative w-12 flex-none">
                      <.record_cover record={rep} width={96} />
                      <.release_groups_badge record={rep} />
                    </div>
                    <div class="min-w-0 flex-auto">
                      <h1 class="truncate text-xs">
                        <.artist_links joinphrase_class="text-xs" artists={rep.artists} />
                      </h1>
                      <h2 class="flex items-center gap-1 text-sm font-medium text-wrap text-zinc-700 dark:text-zinc-300">
                        {rep.title}
                        <.release_status_tooltip record={rep} />
                      </h2>
                      <p class="text-xs/5 text-zinc-500 dark:text-zinc-400">
                        <.released_how_long_ago record={rep} current_date={@current_date} />
                        · {ngettext("1 release", "%{count} releases", length(records))}
                      </p>
                    </div>
                  </div>
                  <div class="flex items-center">
                    <.icon
                      name="hero-chevron-right"
                      class="size-4 text-zinc-400 transition-transform group-open/details:rotate-90"
                    />
                  </div>
                </summary>
                <ul class="ml-1">
                  <li
                    :for={record <- records}
                    phx-click={JS.navigate(@record_show_path.(record))}
                    class="flex items-center cursor-pointer rounded-md px-2 py-1.5 hover:bg-zinc-100 dark:hover:bg-zinc-700"
                    id={record.id}
                  >
                    <div class="w-6 flex-none">
                      <.record_cover record={record} width={48} class="rounded-sm" />
                    </div>
                    <p class="ml-2 text-xs/5 text-zinc-500 dark:text-zinc-400">
                      {format_label(record.format)} · {type_label(record.type)}
                      <span :if={record.purchased_at}>
                        ·
                        <span class="sr-only">
                          {gettext("Purchased on")}
                        </span>
                        <.icon
                          name="hero-banknotes"
                          class="size-4"
                          aria-hidden="true"
                          data-slot="icon"
                        />
                        {Records.Record.format_as_date(record.purchased_at)}
                      </span>
                    </p>
                  </li>
                </ul>
              </details>
            </li>
        <% end %>
      <% end %>
    </ul>
    """
  end

  attr :record, Records.Record, required: true
  attr :current_date, Date, required: true
  attr :record_show_path, :any, required: true

  defp record_on_this_day_item(assigns) do
    ~H"""
    <li
      phx-click={JS.navigate(@record_show_path.(@record))}
      class="flex cursor-pointer justify-between gap-x-6 rounded-md px-2 py-1 hover:bg-zinc-100 dark:hover:bg-zinc-700"
      id={@record.id}
    >
      <div class="flex min-w-0 items-center gap-x-4">
        <div class="relative w-12 flex-none">
          <.record_cover record={@record} width={96} />
          <.release_groups_badge record={@record} />
        </div>
        <div class="min-w-0 flex-auto">
          <h1 class="truncate text-xs">
            <.artist_links joinphrase_class="text-xs" artists={@record.artists} />
          </h1>
          <h2 class="flex items-center gap-1 text-sm font-medium text-wrap text-zinc-700 dark:text-zinc-300">
            {@record.title}
            <.release_status_tooltip record={@record} />
          </h2>
          <p class="text-xs text-zinc-500 dark:text-zinc-400">
            <.released_how_long_ago record={@record} current_date={@current_date} />
            · {format_label(@record.format)} · {type_label(@record.type)}
            <span :if={@record.purchased_at}>
              ·
              <span class="sr-only">
                {gettext("Purchased on")}
              </span>
              <.icon
                name="hero-banknotes"
                class="size-4"
                aria-hidden="true"
                data-slot="icon"
              />
              {Records.Record.format_as_date(@record.purchased_at)}
            </span>
          </p>
        </div>
      </div>
    </li>
    """
  end

  attr :record, Records.Record, required: true
  attr :current_date, Date, required: true

  defp released_how_long_ago(assigns) do
    assigns =
      assign(
        assigns,
        :years,
        Records.Record.released_how_long_ago?(assigns.record, assigns.current_date)
      )

    ~H"""
    <span
      :if={same_year?(@years)}
      class={[
        "text-xs/5",
        "animate-shine bg-linear-to-r from-red-500 via-red-200 to-red-700 bg-clip-text font-semibold text-transparent"
      ]}
    >
      {gettext("Today")}
    </span>
    <span
      :if={!same_year?(@years)}
      class={[
        "text-xs/5",
        normal_year?(@years) && "text-zinc-500 dark:text-zinc-400",
        gold_year?(@years) &&
          "animate-shine bg-linear-to-r from-yellow-500 via-yellow-200 to-yellow-700 bg-clip-text font-semibold text-transparent",
        silver_year?(@years) &&
          "animate-shine bg-linear-to-r from-gray-500 via-gray-200 to-gray-700 bg-clip-text font-semibold text-transparent"
      ]}
    >
      {ngettext(
        "1 year ago",
        "%{count} years ago",
        @years
      )}
    </span>
    """
  end

  defp same_year?(year), do: year == 0
  defp gold_year?(year), do: rem(year, 10) == 0
  defp silver_year?(year), do: rem(year, 5) == 0
  defp normal_year?(year), do: !gold_year?(year) && !silver_year?(year)

  # The Tailwind build step requires all needed classes to be explicitly referenced
  # in the source code, and not dynamically generated. This implies that one cannot
  # (for example) interpolate a number in a class name.
  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defp stats_class(collection) do
    case Enum.count(collection) do
      1 -> "grid-cols-1"
      2 -> "grid-cols-2"
      3 -> "grid-cols-3"
      4 -> "grid-cols-4"
      5 -> "grid-cols-5"
      6 -> "grid-cols-6"
      7 -> "grid-cols-7"
      8 -> "grid-cols-8"
      9 -> "grid-cols-9"
      _other -> ""
    end
  end

  attr :container_class, :string, default: nil
  slot :title, required: true
  slot :side_actions
  slot :inner_block, required: true

  def section(assigns) do
    ~H"""
    <div class={["mt-5", @container_class]}>
      <div class="flex items-center justify-between">
        <h1 class="text-base font-semibold text-zinc-900 lg:text-xl xl:text-2xl dark:text-zinc-200">
          {render_slot(@title)}
        </h1>
        {render_slot(@side_actions)}
      </div>
      {render_slot(@inner_block)}
    </div>
    """
  end
end
