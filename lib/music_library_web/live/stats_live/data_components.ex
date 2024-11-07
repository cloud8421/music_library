defmodule MusicLibraryWeb.StatsLive.DataComponents do
  use MusicLibraryWeb, :live_component

  attr :record, MusicLibrary.Records.Record, required: true
  attr :title, :string, required: true
  attr :class, :string, default: ""

  def album_preview(assigns) do
    ~H"""
    <div
      class={[
        "relative overflow-hidden rounded-md bg-white dark:bg-zinc-800 px-4 pb-3 pt-5 shadow sm:px-6 sm:pt-6 cursor-pointer",
        @class
      ]}
      phx-click={JS.navigate(~p"/records/#{@record}")}
    >
      <dt>
        <img
          class="absolute w-20 rounded-md shadow"
          src={~p"/covers/#{@record.id}"}
          alt={@record.title}
        />
        <p class="ml-24 truncate text-xs sm:text-sm font-medium text-zinc-500 dark:text-zinc-400">
          <%= @title %>
        </p>
      </dt>
      <dd class="ml-24 flex items-baseline pb-6 sm:pb-7">
        <p class="font-semibold">
          <.link
            :for={artist <- @record.artists}
            class="text-sm md:text-base lg:text-2xl text-zinc-900 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200"
            patch={~p"/records?query=mbid:#{artist.musicbrainz_id}"}
          >
            <%= artist.name %>
          </.link>
          <span class="text-sm md:text-base block text-zinc-600 dark:text-zinc-200">
            <%= @record.title %>
          </span>
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
    <div class="overflow-hidden rounded-md bg-white dark:bg-zinc-800 px-4 pb-3 pt-5 shadow sm:px-6 sm:pt-6">
      <dt>
        <p class="truncate text-sm font-medium text-zinc-500 dark:text-zinc-400">
          <%= @title %>
        </p>
      </dt>
      <dd class="flex items-baseline mt-1 pb-6 sm:pb-7">
        <a
          href={@path}
          class="text-2xl font-semibold text-zinc-900 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200"
        >
          <%= @count %>
        </a>
      </dd>
    </div>
    """
  end
end
