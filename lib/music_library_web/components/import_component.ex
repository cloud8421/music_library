defmodule MusicLibraryWeb.ImportComponent do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.RecordComponents,
    only: [toggle_actions_menu: 1, close_actions_menu: 1, format_label: 1, type_label: 1]

  alias MusicBrainz.ReleaseGroupSearchResult
  alias MusicLibrary.Records

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id={:import_form}
        phx-target={@myself}
        phx-change="search"
        phx-submit="search"
        class="px-4"
      >
        <.input
          id={:mb_query}
          name={:mb_query}
          field={@form[:mb_query]}
          type="text"
          label={gettext("Search for a record on MusicBrainz")}
          prompt={gettext("Search for records")}
          phx-debounce="500"
          autocorrect="off"
          autocapitalize="none"
          autofocus
        />
      </.simple_form>
      <ul
        id="release-groups"
        phx-update="stream"
        role="list"
        class="divide-y divide-zinc-100 dark:divide-slate-300/30 mt-5"
      >
        <li
          id="release-groups-empty"
          class="only:flex hidden items-center justify-center h-32 text-md text-zinc-500"
        >
          {gettext("No results")}
        </li>
        <.result
          :for={{id, release_group} <- @streams.release_groups}
          id={id}
          release_group={release_group}
          icon_name={@icon_name}
        />
      </ul>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :icon_name, :string, required: true
  attr :release_group, MusicBrainz.ReleaseGroupSearchResult, required: true

  defp result(assigns) do
    ~H"""
    <li id={@id} class="flex justify-between gap-x-6 py-5 hover:bg-zinc-50 dark:hover:bg-zinc-700">
      <div class="shrink-0 flex items-center justify-between w-full px-4">
        <img
          class="w-20 flex-none rounded-lg mr-4"
          alt={@release_group.title}
          src={ReleaseGroupSearchResult.thumb_url(@release_group)}
          onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
        />
        <div class="min-w-0 flex-auto">
          <h1 class="text-sm leading-6 text-zinc-700 dark:text-zinc-400">
            {@release_group.artists}
          </h1>
          <h2 class="mt-1 flex font-semibold text-sm sm:text-base leading-5 text-zinc-700 dark:text-zinc-300 text-wrap">
            {@release_group.title}
          </h2>
          <p class="mt-1 text-xs leading-5 text-zinc-500 dark:text-zinc-400">
            {Records.Record.format_release(@release_group.release)} · {type_label(@release_group.type)}
          </p>
        </div>
        <div class="relative flex-none">
          <button
            type="button"
            class="text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-300"
            aria-expanded="false"
            aria-haspopup="true"
            phx-click={toggle_actions_menu(@release_group.id)}
            phx-click-away={close_actions_menu(@release_group.id)}
          >
            <span class="sr-only">{gettext("Choose which format to import")}</span>
            <.icon name={@icon_name} class="-mt-1 h-5 w-5" aria-hidden="true" data-slot="icon" />
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
            id={"actions-#{@release_group.id}"}
            class={[
              "hidden pointer-events-auto absolute right-0 z-10 mt-2 w-48 origin-top-right rounded-md bg-white dark:bg-zinc-800 py-2 shadow-lg ring-1 ring-zinc-900/5 focus:outline-hidden"
            ]}
            role="menu"
            aria-orientation="vertical"
            aria-labelledby="options-menu-0-button"
          >
            <.link
              :for={format <- Records.Record.formats()}
              class="block px-3 py-1 text-sm leading-6 text-zinc-900 dark:text-zinc-400 hover:bg-zinc-50 dark:hover:text-zinc-300 dark:hover:bg-zinc-700"
              role="menuitem"
              tabindex="0"
              id={"actions-#{@release_group.id}-#{format}-import"}
              phx-click={
                JS.push("import", value: %{id: @release_group.id, format: format}, page_loading: true)
              }
            >
              {format_label(format)}
            </.link>
          </.focus_wrap>
        </div>
      </div>
    </li>
    """
  end

  attr :type, :string, required: true

  defp type_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center rounded-md bg-zinc-50 px-2 py-1 text-xs font-medium text-zinc-600 ring-1 ring-inset ring-zinc-500/10">
      {@type}
    </span>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> stream_configure(:release_groups,
       dom_id: fn rg -> "musicbrainz_#{rg.id}" end
     )
     |> stream(:release_groups, [])
     |> assign(:form, to_form(%{"mb_query" => ""}))}
  end

  @impl true
  def handle_event("search", %{"mb_query" => mb_query}, socket) do
    {:ok, release_groups} = search(mb_query)

    {:noreply,
     socket
     |> stream(:release_groups, release_groups, reset: true)
     |> assign(:form, to_form(%{"mb_query" => mb_query}))}
  end

  defp search(""), do: {:ok, []}

  defp search(mb_query) do
    MusicBrainz.search_release_group(mb_query, limit: 10)
  end
end
