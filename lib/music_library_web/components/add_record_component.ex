defmodule MusicLibraryWeb.AddRecordComponent do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias MusicBrainz.ReleaseGroupSearchResult
  alias MusicLibrary.Records

  @batch_size 20

  @impl true
  def render(assigns) do
    ~H"""
    <div class="w-86 md:w-2xl">
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
          type="search"
          label={gettext("Search for a record")}
          phx-debounce="500"
          autocomplete="off"
          autofocus
        />
      </.simple_form>
      <ul
        id="release-groups"
        phx-update="stream"
        phx-viewport-bottom={!@loaded_all_results? && "load-more"}
        phx-target={@myself}
        role="list"
        class={[
          "mt-5 divide-y divide-zinc-100 dark:divide-slate-300/30",
          "max-h-[500px] overflow-y-auto"
        ]}
      >
        <.result
          :for={{id, release_group} <- @streams.release_groups}
          id={id}
          release_group={release_group}
          icon_name={@icon_name}
        />
      </ul>
      <div
        :if={@release_groups_count == 0}
        id="release-groups-empty"
        class="flex items-center h-full justify-center h-32 text-md text-zinc-500"
      >
        {gettext("No results")}
      </div>
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
          <h1 class="truncate text-sm leading-6 text-zinc-700 dark:text-zinc-400">
            {@release_group.artists}
          </h1>
          <h2 class="truncate mt-1 flex font-semibold text-sm sm:text-base leading-5 text-zinc-700 dark:text-zinc-300 text-wrap">
            {@release_group.title}
          </h2>
          <p class="mt-1 text-xs leading-5 text-zinc-500 dark:text-zinc-400">
            {Records.Record.format_release_date(@release_group.release_date)} · {type_label(
              @release_group.type
            )}
          </p>
        </div>

        <.actions_menu id={@release_group.id} background_container_target="#records > li">
          <:links>
            <.link
              :for={format <- Records.Record.formats()}
              class="block px-3 py-1 text-sm leading-6 text-zinc-900 dark:text-zinc-400 hover:bg-zinc-50 dark:hover:text-zinc-300 dark:hover:bg-zinc-700"
              role="menuitem"
              tabindex="0"
              id={"actions-#{@release_group.id}-#{format}-import"}
              phx-click={
                JS.dispatch("music_library:confetti")
                |> JS.push("import",
                  value: %{id: @release_group.id, format: format},
                  page_loading: true
                )
              }
            >
              {format_label(format)}
            </.link>
          </:links>
        </.actions_menu>
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
     |> assign(:release_groups_count, 0)
     |> stream(:release_groups, [])
     |> assign(:loaded_all_results?, false)}
  end

  @impl true
  def update(assigns, socket) do
    mb_query = assigns.initial_query || ""

    socket =
      if mb_query == "" do
        socket
      else
        {:ok, release_groups} =
          MusicBrainz.search_release_group(mb_query, limit: @batch_size, offset: 0)

        socket
        |> assign(:release_groups_count, Enum.count(release_groups))
        |> stream(:release_groups, release_groups, reset: true)
      end

    {:ok,
     assign(socket,
       offset: 0,
       icon_name: assigns.icon_name,
       form: to_form(%{"mb_query" => mb_query})
     )}
  end

  @impl true
  def handle_event("search", %{"mb_query" => mb_query}, socket) do
    {:ok, release_groups} =
      MusicBrainz.search_release_group(mb_query, limit: @batch_size, offset: 0)

    {:noreply,
     socket
     |> assign(:offset, 0)
     |> assign(:release_groups_count, length(release_groups))
     |> stream(:release_groups, release_groups, reset: true)
     |> assign(:form, to_form(%{"mb_query" => mb_query}))}
  end

  def handle_event("load-more", _params, socket) do
    %{"mb_query" => mb_query} = socket.assigns.form.params
    offset = socket.assigns.offset + @batch_size

    case MusicBrainz.search_release_group(mb_query, limit: @batch_size, offset: offset) do
      {:ok, release_groups} ->
        {:noreply,
         socket
         |> assign(:offset, offset)
         |> assign(:loaded_all_results?, length(release_groups) < @batch_size)
         |> assign(:release_groups_count, length(release_groups))
         |> stream(:release_groups, release_groups)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end
end
