defmodule MusicLibraryWeb.ArtistLive.RecordComponents do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Records

  attr :records, :list, required: true
  attr :title, :string, required: true
  attr :id, :string, required: true
  attr :record_path, :any, required: true

  def grid(assigns) do
    ~H"""
    <div class="mt-4">
      <h2 class="flex items-end font-semibold text-base sm:text-lg leading-5 text-zinc-700 dark:text-zinc-300">
        {@title}
        <span class="ml-2">
          <span class="sr-only">
            {gettext("Number of records")}
          </span>
          <.round_badge text={Enum.count(@records)} />
        </span>
      </h2>
      <%!-- TODO: replace with OSS version --%>
      <ul
        id={@id}
        role="list"
        class="mt-4 grid grid-cols-3 gap-x-4 gap-y-8 sm:grid-cols-4 sm:gap-x-6 lg:grid-cols-6 xl:gap-x-8"
      >
        <li :for={record <- @records} class="relative">
          <div class="group overflow-hidden rounded-lg bg-zinc-100 focus-within:ring-2 focus-within:ring-zinc-500 focus-within:ring-offset-2 focus-within:ring-offset-zinc-100">
            <img
              alt={record.title}
              src={~p"/covers/#{record.id}?vsn=#{record.cover_hash}"}
              class="pointer-events-none aspect-square object-cover group-hover:opacity-75"
            />
            <button
              type="button"
              class="absolute inset-0 focus:outline-none"
              phx-click={JS.navigate(@record_path.(record))}
            >
              <span class="sr-only">{gettext("View details")}</span>
            </button>
          </div>
          <p class="pointer-events-none mt-2 block truncate text-sm font-medium text-zinc-900 dark:text-zinc-300">
            {record.title}
          </p>
          <p class="pointer-events-none block text-sm font-medium text-zinc-500">
            {Records.Record.format_long_label(record.format)} · {Records.Record.type_long_label(
              record.type
            )}
          </p>
          <p class="pointer-events-none block text-sm font-medium text-zinc-500">
            {Records.Record.format_release(record.release)}
          </p>
        </li>
      </ul>
    </div>
    """
  end
end
