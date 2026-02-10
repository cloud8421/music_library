defmodule MusicLibraryWeb.SearchComponents do
  @moduledoc """
  Universal search modal and related components.
  """

  use MusicLibraryWeb, :html

  import MusicLibraryWeb.RecordComponents,
    only: [format_label: 1, type_label: 1, record_cover: 1, artist_image: 1]

  alias MusicLibrary.Records.Record
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
        "p-3 rounded-lg cursor-pointer transition-colors",
        "hover:bg-zinc-50 dark:hover:bg-zinc-700",
        "aria-selected:bg-zinc-200 dark:aria-selected:bg-zinc-700"
      ]}
      role="option"
      {@rest}
    >
      <div class="flex items-center space-x-3">
        <div class="shrink-0">
          <.record_cover
            record={@record}
            class="w-12 h-12 rounded-md aspect-square object-cover"
            width={96}
          />
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium text-zinc-900 dark:text-zinc-100 truncate">
            {@record.title}
          </p>
          <p class="text-sm text-zinc-500 font-medium dark:text-zinc-400 truncate">
            {Record.artist_names(@record)}
          </p>
          <p class="pointer-events-none block text-sm text-zinc-500">
            {format_label(@record.format)} · {type_label(@record.type)} · {Record.format_release_date(
              @record.release_date
            )}
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
        "p-3 rounded-lg cursor-pointer transition-colors",
        "hover:bg-zinc-50 dark:hover:bg-zinc-700",
        "aria-selected:bg-zinc-200 dark:aria-selected:bg-zinc-700"
      ]}
      role="option"
      {@rest}
    >
      <div class="flex items-center space-x-3">
        <div class="shrink-0">
          <.artist_image
            class="w-12 h-12 rounded-md aspect-square object-cover"
            artist={@artist}
            width={96}
            image_hash={@image_data_hash}
          />
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium text-zinc-900 dark:text-zinc-100 truncate">
            {@artist.name}
          </p>
          <p :if={@artist.disambiguation} class="text-sm text-zinc-500 dark:text-zinc-400 truncate">
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
        "p-3 rounded-lg cursor-pointer transition-colors",
        "hover:bg-zinc-50 dark:hover:bg-zinc-700",
        "aria-selected:bg-zinc-200 dark:aria-selected:bg-zinc-700"
      ]}
      role="option"
      {@rest}
    >
      <div class="flex items-center space-x-3">
        <div class="shrink-0 w-12 h-12 rounded-md bg-zinc-100 dark:bg-zinc-700 flex items-center justify-center">
          <.icon name="hero-queue-list" class="h-6 w-6 text-zinc-400 dark:text-zinc-500" />
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium text-zinc-900 dark:text-zinc-100 truncate">
            {@record_set.name}
          </p>
          <div
            :if={@record_set.description}
            class="prose prose-zinc dark:prose-invert prose-sm"
          >
            {render_description(@record_set.description)}
          </div>
        </div>
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
      <h3 class="text-sm font-medium text-zinc-700 dark:text-zinc-300 mb-1 uppercase tracking-wide">
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

      <div :for={action <- @actions} class="px-2 mt-2">
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
      class="aria-selected:bg-zinc-200 dark:aria-selected:bg-zinc-700 text-sm text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 transition-colors"
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

  def results_footer(assigns) do
    ~H"""
    <div class="p-2 bg-zinc-50 dark:bg-zinc-900 rounded-b-lg border-t border-zinc-200 dark:border-zinc-700">
      <div class="flex items-center justify-between text-xs text-zinc-500 dark:text-zinc-400">
        <div class="flex items-center space-x-4">
          <div :if={@total_results > 0} class="flex items-center">
            <kbd class="px-2 py-1 bg-zinc-200 dark:bg-zinc-700 rounded">↑</kbd>
            <kbd class="px-2 py-1 bg-zinc-200 dark:bg-zinc-700 rounded ml-1">↓</kbd>
            <span class="ml-1">{gettext("Navigate")}</span>
          </div>
          <div :if={@total_results > 0} class="flex items-center">
            <kbd class="px-2 py-1 bg-zinc-200 dark:bg-zinc-700 rounded">Enter</kbd>
            <span class="ml-1">{gettext("Select")}</span>
          </div>
          <div class="flex items-center">
            <kbd class="px-2 py-1 bg-zinc-200 dark:bg-zinc-700 rounded">Esc</kbd>
            <span class="ml-1">{gettext("Close")}</span>
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
      <.icon name="hero-magnifying-glass" class="h-12 w-12 text-zinc-400 mx-auto mb-4" />
      <p class="text-sm text-zinc-500 dark:text-zinc-500 mt-2">
        <kbd class="px-2 py-1 bg-zinc-100 dark:bg-zinc-700 rounded text-xs">Cmd/Ctrl+K</kbd>
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

  def no_results(assigns) do
    ~H"""
    <div class="p-8 text-center">
      <.icon name="hero-face-frown" class="h-12 w-12 text-zinc-400 mx-auto mb-4" />
      <p class="text-zinc-600 dark:text-zinc-400">
        {gettext("No results found for '%{query}'", query: @query)}
      </p>
      <.link
        class="text-sm font-medium text-zinc-900 dark:text-zinc-100 truncate"
        navigate={~p"/wishlist/import?#{[import_query: @query]}"}
      >
        {gettext("Add a record instead", query: @query)}
      </.link>
    </div>
    """
  end

  defp render_description(description) do
    description
    |> String.slice(0, 100)
    |> Markdown.to_html()
    |> raw()
  end
end
