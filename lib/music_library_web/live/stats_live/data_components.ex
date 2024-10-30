defmodule MusicLibraryWeb.StatsLive.DataComponents do
  use MusicLibraryWeb, :live_component

  attr :data, :list,
    required: true,
    doc: """
      A list of tuples, where the first element is label and the second is the count.
    """

  attr :title, :string, required: true
  attr :col_class, :string

  def stats_grid(assigns) do
    ~H"""
    <div>
      <h1 class="mt-5 text-base lg:text-2xl text-gray-900 dark:text-gray-200 font-semibold">
        <%= @title %>
      </h1>
      <dl class={[
        "grid",
        @col_class,
        "mt-5 divide-x divide-gray-200 dark:divide-slate-300/50 overflow-hidden rounded-md",
        "bg-white dark:bg-zinc-700 shadow"
      ]}>
        <div :for={{format, count} <- @data} class="px-2 py-5 sm:px-4">
          <dt class="text-sm font-medium text-gray-500 dark:text-gray-400 text-center max-sm:text-xs break-keep">
            <%= format %>
          </dt>
          <dd class="mt-1 text-center">
            <a
              class="text-xl lg:text-2xl font-semibold hover:text-gray-500 dark:text-gray-300 dark:hover:text-gray-200"
              href={~p"/records?query=format:#{format}"}
            >
              <%= count %>
            </a>
          </dd>
        </div>
      </dl>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :count, :integer, required: true
  attr :path, :string, required: true

  def counter(assigns) do
    ~H"""
    <div class="overflow-hidden rounded-md bg-white dark:bg-zinc-700 px-4 pb-3 pt-5 shadow sm:px-6 sm:pt-6">
      <dt>
        <p class="truncate text-sm font-medium text-gray-500 dark:text-gray-400">
          <%= @title %>
        </p>
      </dt>
      <dd class="flex items-baseline mt-1 pb-6 sm:pb-7">
        <a
          href={@path}
          class="text-2xl font-semibold text-gray-900 hover:text-gray-500 dark:text-gray-300 dark:hover:text-gray-200"
        >
          <%= @count %>
        </a>
      </dd>
    </div>
    """
  end
end
