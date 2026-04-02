defmodule MusicLibraryWeb.SearchComponents do
  @moduledoc """
  Universal search modal and related components.
  """

  use MusicLibraryWeb, :html

  import MusicLibraryWeb.RecordComponents,
    only: [
      format_label: 1,
      type_label: 1,
      record_cover: 1,
      artist_image: 1,
      release_status_tooltip: 1
    ]

  alias MusicLibrary.Records.Record
  alias MusicLibraryWeb.Components.BarcodeScanner
  alias MusicLibraryWeb.Markdown

  @doc """
  Renders a search result item for records.

  ## Examples

      <.search_result_record record={record} />
  """
  attr :record, :map, required: true
  attr :type, :atom, required: true, values: [:collection, :wishlist]
  attr :rest, :global, include: ~w(phx-click phx-value-id)

  def search_result_record(assigns) do
    ~H"""
    <div
      class={[
        "cursor-pointer rounded-lg p-3 transition-colors",
        "hover:bg-zinc-100 dark:hover:bg-zinc-700",
        "aria-selected:bg-zinc-200 dark:aria-selected:bg-zinc-700"
      ]}
      role="option"
      {@rest}
    >
      <div class="flex items-center space-x-3">
        <div class="shrink-0">
          <.record_cover
            record={@record}
            class="aspect-square size-12 rounded-md object-cover"
            width={96}
          />
        </div>
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm font-medium text-zinc-900 dark:text-zinc-100">
            {@record.title} <.release_status_tooltip record={@record} />
          </p>
          <p class="truncate text-sm font-medium text-zinc-500 dark:text-zinc-400">
            {Record.artist_names(@record)}
          </p>
          <p class="pointer-events-none block text-sm text-zinc-500 dark:text-zinc-400">
            {format_label(@record.format)} · {type_label(@record.type)} ·
            <.icon
              name="hero-calendar-days"
              class="-mt-1 size-4"
              aria-hidden="true"
              data-slot="icon"
            />
            {Record.format_release_date(@record.release_date)}
            <span :if={@record.purchased_at}>
              ·
              <.icon
                name="hero-banknotes"
                class="size-4"
                aria-hidden="true"
                data-slot="icon"
              />
              {Record.format_as_date(@record.purchased_at)}
            </span>
          </p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a search result item for artists.

  ## Examples

      <.search_result_artist artist={artist} />
  """
  attr :artist, :map, required: true
  attr :image_data_hash, :string, required: false
  attr :rest, :global, include: ~w(phx-click phx-value-id)

  def search_result_artist(assigns) do
    ~H"""
    <div
      class={[
        "cursor-pointer rounded-lg p-3 transition-colors",
        "hover:bg-zinc-100 dark:hover:bg-zinc-700",
        "aria-selected:bg-zinc-200 dark:aria-selected:bg-zinc-700"
      ]}
      role="option"
      {@rest}
    >
      <div class="flex items-center space-x-3">
        <div class="shrink-0">
          <.artist_image
            class="aspect-square size-12 rounded-md object-cover"
            artist={@artist}
            width={96}
            image_hash={@image_data_hash}
          />
        </div>
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm font-medium text-zinc-900 dark:text-zinc-100">
            {@artist.name}
          </p>
          <p :if={@artist.disambiguation} class="truncate text-sm text-zinc-500 dark:text-zinc-400">
            {@artist.disambiguation}
          </p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a search result item for record sets.

  ## Examples

      <.search_result_record_set record_set={record_set} />
  """
  attr :record_set, :map, required: true
  attr :rest, :global, include: ~w(phx-click phx-value-id)

  def search_result_record_set(assigns) do
    ~H"""
    <div
      class={[
        "cursor-pointer rounded-lg p-3 transition-colors",
        "hover:bg-zinc-100 dark:hover:bg-zinc-700",
        "aria-selected:bg-zinc-200 dark:aria-selected:bg-zinc-700"
      ]}
      role="option"
      {@rest}
    >
      <div class="flex items-center space-x-3">
        <div class="flex size-12 shrink-0 items-center justify-center rounded-md bg-zinc-100 dark:bg-zinc-700">
          <.icon name="hero-queue-list" class="size-6 text-zinc-400 dark:text-zinc-500" />
        </div>
        <div class="min-w-0 flex-1">
          <p class="truncate text-sm font-medium text-zinc-900 dark:text-zinc-100">
            {@record_set.name}
          </p>
          <div
            :if={@record_set.description}
            class="dark:prose-invert prose prose-sm prose-zinc"
          >
            {render_description(@record_set.description)}
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a search result item for navigation links.

  ## Examples

      <.search_result_navigation label="Collection" icon="hero-circle-stack" />
  """
  attr :label, :string, required: true
  attr :icon, :string, default: nil
  attr :rest, :global, include: ~w(phx-click phx-value-path phx-target)

  slot :custom_icon

  def search_result_navigation(assigns) do
    ~H"""
    <div
      class={[
        "cursor-pointer rounded-lg p-3 transition-colors",
        "hover:bg-zinc-100 dark:hover:bg-zinc-700",
        "aria-selected:bg-zinc-200 dark:aria-selected:bg-zinc-700"
      ]}
      role="option"
      {@rest}
    >
      <div class="flex items-center space-x-3">
        <div class="flex size-8 shrink-0 items-center justify-center rounded-md bg-zinc-100 dark:bg-zinc-700">
          <%= if @icon do %>
            <.icon name={@icon} class="size-4 text-zinc-500 dark:text-zinc-400" />
          <% else %>
            {render_slot(@custom_icon)}
          <% end %>
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium text-zinc-900 dark:text-zinc-100">
            {@label}
          </p>
        </div>
        <span class="text-xs text-zinc-400 dark:text-zinc-500">
          {gettext("Go to →")}
        </span>
      </div>
    </div>
    """
  end

  @doc """
  Renders a search result group with a title and items.

  ## Examples

      <.search_result_group title="Collection" count={3} total_count={10}>
        <.search_result_record :for={record <- @records} record={record} />
        <:actions>
          <button phx-click="view_all">View all results</button>
        </:actions>
      </.search_result_group>
  """
  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :total_count, :integer, default: nil
  attr :class, :string, default: ""

  slot :inner_block, required: true
  slot :actions, doc: "Actions like 'view all' buttons"

  def search_result_group(assigns) do
    ~H"""
    <div class={["p-2", @class]}>
      <h3 class="mb-1 text-sm font-medium tracking-wide text-zinc-700 uppercase dark:text-zinc-300">
        {@title}
        <span :if={@total_count && @total_count > @count}>
          {gettext("(%{count} of %{total})", count: @count, total: @total_count)}
        </span>
        <span :if={@total_count && @total_count <= @count}>
          ({@count})
        </span>
      </h3>

      <div class="space-y-1" role="listbox">
        {render_slot(@inner_block)}
      </div>

      <div :for={action <- @actions} class="mt-2 px-2">
        {render_slot(action)}
      </div>
    </div>
    """
  end

  @doc """
  Renders a view all results button.

  ## Examples

      <.view_all_button count={25} target="collection" />
  """
  attr :count, :integer, required: true
  attr :target, :string, required: true
  attr :rest, :global, include: ~w(phx-click phx-value-query)

  def view_all_button(assigns) do
    ~H"""
    <button
      role="option"
      class="text-sm text-blue-600 transition-colors hover:text-blue-800 aria-selected:bg-zinc-200 dark:text-blue-400 dark:hover:text-blue-300 dark:aria-selected:bg-zinc-700"
      {@rest}
    >
      {gettext("View all %{count} %{target} results →", count: @count, target: @target)}
    </button>
    """
  end

  @doc """
  Renders keyboard shortcut hints.

  ## Examples

      <.results_footer />
  """
  attr :total_results, :integer, default: 0
  attr :has_navigable_items, :boolean, default: false

  def results_footer(assigns) do
    assigns =
      assign(assigns, :show_nav_hints, assigns.total_results > 0 or assigns.has_navigable_items)

    ~H"""
    <div class="rounded-b-lg border-t border-zinc-200 bg-zinc-50 p-2 dark:border-zinc-700 dark:bg-zinc-900">
      <div class="flex items-center justify-between text-xs text-zinc-500 dark:text-zinc-400">
        <div class="flex items-center space-x-4">
          <div :if={@show_nav_hints} class="flex items-center gap-1">
            <kbd class="rounded bg-zinc-200 px-2 py-1 dark:bg-zinc-700">↑</kbd>
            <kbd class="rounded bg-zinc-200 px-2 py-1 dark:bg-zinc-700">↓</kbd>
            <span>{gettext("Navigate")}</span>
          </div>
          <div :if={@show_nav_hints} class="flex items-center gap-1">
            <kbd class="rounded bg-zinc-200 px-2 py-1 dark:bg-zinc-700">Enter</kbd>
            <span>{gettext("Select")}</span>
          </div>
          <div class="flex items-center gap-1">
            <kbd class="rounded bg-zinc-200 px-2 py-1 dark:bg-zinc-700">Esc</kbd>
            <span>{gettext("Close")}</span>
          </div>
        </div>
        <div :if={@total_results > 0} class="text-zinc-500 dark:text-zinc-400">
          {ngettext("1 result", "%{count} results", @total_results)}
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders an empty search state.

  ## Examples

      <.empty_state />
  """
  def empty_state(assigns) do
    ~H"""
    <div class="p-8 text-center">
      <.icon name="hero-magnifying-glass" class="mx-auto mb-4 size-12 text-zinc-400" />
      <p class="mt-2 text-sm text-zinc-500 dark:text-zinc-500">
        <kbd class="rounded bg-zinc-100 px-2 py-1 text-xs dark:bg-zinc-700">Cmd/Ctrl+K</kbd>
        {gettext("to open this search")}
      </p>
    </div>
    """
  end

  @doc """
  Renders a no results state.

  ## Examples

      <.no_results query="radiohead" />
  """
  attr :query, :string, required: true
  attr :target, :any, required: true

  def no_results(assigns) do
    ~H"""
    <div class="m-4 p-4 text-center">
      <.icon name="hero-face-frown" class="mx-auto mb-4 size-12 text-zinc-400" />
      <p class="text-zinc-600 dark:text-zinc-400">
        {gettext("No results found for '%{query}'", query: @query)}
      </p>
    </div>
    <.search_result_group title={gettext("Quick actions")} count={4}>
      <.search_result_navigation
        label={gettext("Add to wishlist")}
        icon="hero-star"
        phx-click="navigate_to_link"
        phx-value-path={~p"/wishlist/import?#{[import_query: @query]}"}
        phx-target={@target}
      />
      <.search_result_navigation
        label={gettext("Add to collection")}
        icon="hero-plus-circle"
        phx-click="navigate_to_link"
        phx-value-path={~p"/collection/import?#{[import_query: @query]}"}
        phx-target={@target}
      />
      <.search_result_navigation
        label={gettext("Search to scrobble")}
        icon="hero-play"
        phx-click="navigate_to_link"
        phx-value-path={~p"/scrobble?#{[query: @query]}"}
        phx-target={@target}
      />
      <.search_result_navigation
        label={gettext("Scan a record")}
        phx-click="navigate_to_link"
        phx-value-path={~p"/collection/scan"}
        phx-target={@target}
      >
        <:custom_icon>
          <BarcodeScanner.barcode_icon class="size-4 fill-zinc-500 dark:fill-zinc-400" />
        </:custom_icon>
      </.search_result_navigation>
    </.search_result_group>
    """
  end

  # sobelow_skip ["XSS.Raw"]
  # Markdown.to_html/1 sanitizes HTML via MDEx (ammonia)
  defp render_description(description) do
    description
    |> String.slice(0, 100)
    |> Markdown.to_html()
    |> raw()
  end
end
