defmodule MusicLibraryWeb.StatsLive.DataComponents do
  use MusicLibraryWeb, :live_component

  attr :record, MusicLibrary.Records.Record, required: true
  attr :title, :string, required: true
  attr :class, :string

  def album_preview(assigns) do
    ~H"""
    <div
      class={[
        "relative overflow-hidden rounded-md bg-white dark:bg-zinc-800 px-4 pb-3 pt-5 shadow sm:px-6 sm:pt-6 cursor-pointer",
        @class
      ]}
      phx-click={JS.navigate(~p"/collection/#{@record}")}
    >
      <dt>
        <img
          class="absolute w-20 rounded-md shadow"
          src={~p"/covers/#{@record.id}?vsn=#{@record.cover_hash}"}
          alt={@record.title}
        />
        <p class="ml-24 truncate text-xs sm:text-sm font-medium text-zinc-500 dark:text-zinc-400">
          {@title}
        </p>
      </dt>
      <dd class="ml-24 flex items-baseline pb-6 sm:pb-7">
        <p class="font-semibold">
          <.link
            :for={artist <- @record.artists}
            class="text-sm md:text-base lg:text-2xl text-zinc-900 hover:text-zinc-500 dark:text-zinc-300 dark:hover:text-zinc-200"
            navigate={~p"/artists/#{artist.musicbrainz_id}"}
          >
            {artist.name}
          </.link>
          <span class="text-sm md:text-base block text-zinc-600 dark:text-zinc-200">
            {@record.title}
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

  attr :color, :atom, values: [:green, :yellow, :gray], required: true
  attr :text, :string, required: true

  def badge(assigns) do
    case assigns.color do
      :green ->
        ~H"""
        <span class={[
          "inline-flex items-center rounded-md",
          "px-2 py-1 text-xs font-medium",
          "ring-1 ring-inset",
          "bg-green-50 dark:bg-green-500/10",
          "text-green-700 dark:text-green-400",
          "ring-green-600/20 dark:ring-green-500/20"
        ]}>
          {@text}
        </span>
        """

      :yellow ->
        ~H"""
        <span class={[
          "inline-flex items-center rounded-md",
          "px-2 py-1 text-xs font-medium",
          "ring-1 ring-inset",
          "bg-yellow-50 dark:bg-yellow-400/10",
          "text-yellow-800 dark:text-yellow-500",
          "ring-yellow-600/20 dark:ring-yellow-400/20"
        ]}>
          {@text}
        </span>
        """

      :gray ->
        ~H"""
        <span class={[
          "inline-flex items-center rounded-md",
          "px-2 py-1 text-xs font-medium",
          "ring-1 ring-inset",
          "bg-zinc-50 dark:bg-zinc-500/10",
          "text-zinc-700 dark:text-zinc-400",
          "ring-zinc-600/20 dark:ring-zinc-500/20"
        ]}>
          {@text}
        </span>
        """
    end
  end
end
