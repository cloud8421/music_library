defmodule MusicLibraryWeb.SearchComponents do
  @moduledoc """
  Universal search modal and related components.
  """
  use Phoenix.Component
  use Gettext, backend: MusicLibraryWeb.Gettext

  import MusicLibraryWeb.CoreComponents, only: [icon: 1]

  @doc """
  Renders a search trigger button that opens the universal search modal.

  ## Examples

      <.search_trigger />
  """
  attr :class, :string, default: ""
  attr :rest, :global, include: ~w(phx-click phx-target)

  def search_trigger(assigns) do
    ~H"""
    <button
      type="button"
      class={[
        "flex items-center justify-center h-9 w-9 rounded-lg",
        "text-gray-500 dark:text-gray-400",
        "hover:text-gray-700 dark:hover:text-gray-300",
        "hover:bg-gray-100 dark:hover:bg-gray-800",
        "focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 dark:focus:ring-offset-gray-900",
        "transition-colors duration-200",
        @class
      ]}
      title="Search (Ctrl+K)"
      {@rest}
    >
      <.icon name="hero-magnifying-glass" class="h-5 w-5" />
    </button>
    """
  end

  @doc """
  Renders a search result item for records.

  ## Examples

      <.search_result_record record={record} selected={false} />
  """
  attr :record, :map, required: true
  attr :selected, :boolean, default: false
  attr :type, :atom, required: true, values: [:collection, :wishlist]
  attr :rest, :global, include: ~w(phx-click phx-value-id)

  def search_result_record(assigns) do
    ~H"""
    <div
      class={[
        "p-3 rounded-lg cursor-pointer transition-colors",
        "hover:bg-gray-50 dark:hover:bg-gray-700",
        if(@selected, do: "bg-blue-50 dark:bg-blue-900", else: "")
      ]}
      {@rest}
    >
      <div class="flex items-center space-x-3">
        <div class="flex-shrink-0">
          <.icon
            name={if @type == :collection, do: "hero-musical-note", else: "hero-heart"}
            class={"h-5 w-5 #{if @type == :collection, do: "text-green-500", else: "text-red-500"}"}
          />
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium text-gray-900 dark:text-gray-100 truncate">
            {@record.title}
          </p>
          <p class="text-sm text-gray-500 dark:text-gray-400 truncate">
            {@record.artists |> Enum.map(& &1.name) |> Enum.join(", ")}
          </p>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a search result item for artists.

  ## Examples

      <.search_result_artist artist={artist} selected={false} />
  """
  attr :artist, :map, required: true
  attr :selected, :boolean, default: false
  attr :rest, :global, include: ~w(phx-click phx-value-id)

  def search_result_artist(assigns) do
    ~H"""
    <div
      class={[
        "p-3 rounded-lg cursor-pointer transition-colors",
        "hover:bg-gray-50 dark:hover:bg-gray-700",
        if(@selected, do: "bg-blue-50 dark:bg-blue-900", else: "")
      ]}
      {@rest}
    >
      <div class="flex items-center space-x-3">
        <div class="flex-shrink-0">
          <.icon name="hero-user" class="h-5 w-5 text-blue-500" />
        </div>
        <div class="min-w-0 flex-1">
          <p class="text-sm font-medium text-gray-900 dark:text-gray-100 truncate">
            {@artist.name}
          </p>
          <p :if={@artist.disambiguation} class="text-sm text-gray-500 dark:text-gray-400 truncate">
            {@artist.disambiguation}
          </p>
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
    <div class={["p-4", @class]}>
      <h3 class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3 uppercase tracking-wide">
        {@title} ({@count}
        <span :if={@total_count && @total_count > @count}>
          of <%= @total_count %>
        </span>)
      </h3>

      <div class="space-y-2">
        {render_slot(@inner_block)}
      </div>

      <div :for={action <- @actions} class="mt-3">
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
      class="text-sm text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-300 transition-colors"
      {@rest}
    >
      View all {@count} {@target} results →
    </button>
    """
  end

  @doc """
  Renders keyboard shortcut hints.

  ## Examples

      <.keyboard_shortcuts />
  """
  attr :total_results, :integer, default: 0

  def keyboard_shortcuts(assigns) do
    ~H"""
    <div class="p-4 bg-gray-50 dark:bg-gray-900 rounded-b-lg border-t border-gray-200 dark:border-gray-700">
      <div class="flex items-center justify-between text-xs text-gray-500 dark:text-gray-400">
        <div class="flex items-center space-x-4">
          <div class="flex items-center">
            <kbd class="px-2 py-1 bg-gray-200 dark:bg-gray-700 rounded">↑↓</kbd>
            <span class="ml-1">Navigate</span>
          </div>
          <div class="flex items-center">
            <kbd class="px-2 py-1 bg-gray-200 dark:bg-gray-700 rounded">↵</kbd>
            <span class="ml-1">Select</span>
          </div>
          <div class="flex items-center">
            <kbd class="px-2 py-1 bg-gray-200 dark:bg-gray-700 rounded">Esc</kbd>
            <span class="ml-1">Close</span>
          </div>
        </div>
        <div :if={@total_results > 0} class="text-gray-500 dark:text-gray-400">
          {@total_results} results
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
      <.icon name="hero-magnifying-glass" class="h-12 w-12 text-gray-400 mx-auto mb-4" />
      <p class="text-gray-600 dark:text-gray-400">Start typing to search your records and artists</p>
      <p class="text-sm text-gray-500 dark:text-gray-500 mt-2">
        Use <kbd class="px-2 py-1 bg-gray-100 dark:bg-gray-700 rounded text-xs">Ctrl+K</kbd>
        to open this search
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
      <.icon name="hero-face-frown" class="h-12 w-12 text-gray-400 mx-auto mb-4" />
      <p class="text-gray-600 dark:text-gray-400">No results found for "{@query}"</p>
      <p class="text-sm text-gray-500 dark:text-gray-500 mt-2">
        Try a different search term or check your spelling
      </p>
    </div>
    """
  end

  @doc """
  Renders a loading state.

  ## Examples

      <.loading_state />
  """
  def loading_state(assigns) do
    ~H"""
    <div class="p-8 text-center">
      <div class="animate-spin rounded-full h-8 w-8 border-b-2 border-blue-500 mx-auto"></div>
      <p class="mt-4 text-gray-600 dark:text-gray-400">Searching...</p>
    </div>
    """
  end
end
