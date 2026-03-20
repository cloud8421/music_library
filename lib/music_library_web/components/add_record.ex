defmodule MusicLibraryWeb.Components.AddRecord do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]
  import MusicLibraryWeb.SearchComponents, only: [results_footer: 1]

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
      <.alert :if={@error_message} color="danger" hide_close class="mx-4 mt-4">
        {@error_message}
      </.alert>
      <ul
        id="release-groups"
        phx-update="stream"
        phx-viewport-bottom={!@loaded_all_results? && "load-more"}
        phx-target={@myself}
        role="list"
        class={[
          "mt-5 divide-y divide-zinc-100 dark:divide-slate-300/30",
          "max-h-125 overflow-y-auto"
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
        class="text-md flex h-32 items-center justify-center text-zinc-500 md:h-64"
      >
        {gettext("No results")}
      </div>
      <.results_footer total_results={@release_groups_total_count} />
    </div>
    """
  end

  attr :id, :string, required: true
  attr :icon_name, :string, required: true
  attr :release_group, MusicBrainz.ReleaseGroupSearchResult, required: true

  defp result(assigns) do
    ~H"""
    <li id={@id} class="flex justify-between gap-x-6 py-5 hover:bg-zinc-50 dark:hover:bg-zinc-700">
      <div class="flex w-full shrink-0 items-center justify-between px-4">
        <img
          class="mr-4 w-20 flex-none rounded-lg"
          alt={@release_group.title}
          src={ReleaseGroupSearchResult.thumb_url(@release_group)}
          onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
        />
        <div class="min-w-0 flex-auto">
          <h1 class="truncate text-sm/6 text-zinc-700 dark:text-zinc-400">
            {@release_group.artists}
          </h1>
          <h2 class="mt-1 flex truncate text-sm/5 font-semibold text-wrap text-zinc-700 sm:text-base dark:text-zinc-300">
            {@release_group.title}
          </h2>
          <p class="mt-1 text-xs/5 text-zinc-500 dark:text-zinc-400">
            {Records.Record.format_release_date(@release_group.release_date)} · {type_label(
              @release_group.type
            )}
          </p>
        </div>

        <.dropdown id={"actions-#{@release_group.id}"} placement="bottom-end">
          <:toggle>
            <span class="sr-only">{gettext("Choose which format to import")}</span>
            <.icon
              name="hero-plus"
              class="size-5 cursor-pointer text-zinc-500 dark:text-zinc-400"
              aria-hidden="true"
              data-slot="icon"
            />
          </:toggle>
          <.focus_wrap id={"actions-#{@release_group.id}-focus-wrap"}>
            <.dropdown_link
              :for={format <- Records.Record.formats()}
              id={"actions-#{@release_group.id}-#{format}-import"}
              phx-click={
                JS.push("import", value: %{id: @release_group.id, format: format}, page_loading: true)
              }
            >
              {format_label(format)}
            </.dropdown_link>
          </.focus_wrap>
        </.dropdown>
      </div>
    </li>
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
     |> assign(:release_groups_total_count, 0)
     |> stream(:release_groups, [])
     |> assign(:loaded_all_results?, false)
     |> assign(:error_message, nil)}
  end

  @impl true
  def update(assigns, socket) do
    mb_query = assigns.initial_query || ""

    socket =
      if mb_query == "" do
        socket
      else
        case MusicBrainz.search_release_group(mb_query, limit: @batch_size, offset: 0) do
          {:ok, result} ->
            socket
            |> assign(:error_message, nil)
            |> assign(:release_groups_count, Enum.count(result.release_groups))
            |> assign(:release_groups_total_count, result.total_count)
            |> stream(:release_groups, result.release_groups, reset: true)

          {:error, _reason} ->
            assign(
              socket,
              :error_message,
              gettext("Could not search MusicBrainz. Please try again.")
            )
        end
      end

    {:ok,
     assign(socket,
       offset: 0,
       icon_name: assigns.icon_name,
       form: to_form(%{"mb_query" => mb_query})
     )}
  end

  @impl true

  def handle_event("search", %{"mb_query" => ""}, socket) do
    {:noreply,
     socket
     |> assign(:offset, 0)
     |> assign(:release_groups_count, 0)
     |> assign(:release_groups_total_count, 0)
     |> stream(:release_groups, [], reset: true)
     |> assign(:form, to_form(%{"mb_query" => ""}))}
  end

  def handle_event("search", %{"mb_query" => mb_query}, socket) do
    case MusicBrainz.search_release_group(mb_query, limit: @batch_size, offset: 0) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:error_message, nil)
         |> assign(:offset, 0)
         |> assign(:release_groups_count, length(result.release_groups))
         |> assign(:release_groups_total_count, result.total_count)
         |> stream(:release_groups, result.release_groups, reset: true)
         |> assign(:form, to_form(%{"mb_query" => mb_query}))}

      {:error, _reason} ->
        {:noreply,
         socket
         |> assign(:error_message, gettext("Could not search MusicBrainz. Please try again."))
         |> assign(:offset, 0)
         |> assign(:release_groups_count, 0)
         |> assign(:release_groups_total_count, 0)
         |> stream(:release_groups, [], reset: true)
         |> assign(:form, to_form(%{"mb_query" => mb_query}))}
    end
  end

  def handle_event("load-more", _params, socket) do
    %{"mb_query" => mb_query} = socket.assigns.form.params
    offset = socket.assigns.offset + @batch_size

    case MusicBrainz.search_release_group(mb_query, limit: @batch_size, offset: offset) do
      {:ok, result} ->
        {:noreply,
         socket
         |> assign(:offset, offset)
         |> assign(:loaded_all_results?, length(result.release_groups) < @batch_size)
         |> assign(:release_groups_count, offset + length(result.release_groups))
         |> assign(:release_groups_total_count, result.total_count)
         |> stream(:release_groups, result.release_groups)}

      {:error, _reason} ->
        {:noreply, socket}
    end
  end
end
