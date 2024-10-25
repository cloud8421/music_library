defmodule MusicLibraryWeb.RecordLive.ImportComponent do
  use MusicLibraryWeb, :live_component

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
        />
      </.simple_form>
      <ul
        :if={@release_groups !== []}
        role="list"
        class="divide-y divide-gray-100 dark:divide-slate-300/30 mt-5"
      >
        <.result :for={release_group <- @release_groups} release_group={release_group} />
      </ul>
      <div
        :if={@release_groups == []}
        class="flex items-center justify-center h-32 text-md text-zinc-500"
      >
        <%= gettext("No results") %>
      </div>
    </div>
    """
  end

  defp result(assigns) do
    ~H"""
    <li
      id={"musicbrainz_" <> @release_group.id}
      class="flex justify-between gap-x-6 py-5 hover:bg-gray-50 dark:hover:bg-zinc-700"
    >
      <div class="shrink-0 flex items-center justify-between w-full px-4">
        <div class="min-w-0 flex-auto">
          <h1 class="text-sm leading-6 text-zinc-700 dark:text-zinc-400">
            <%= @release_group.artists %>
          </h1>
          <h2 class="mt-1 flex font-semibold text-sm sm:text-base leading-5 text-zinc-700 dark:text-zinc-300 text-wrap">
            <%= @release_group.title %>
          </h2>
          <p class="mt-1 text-xs leading-5 text-zinc-500 dark:text-zinc-400">
            <%= Records.Record.format_release(@release_group.release) %> · <%= Records.Record.type_long_label(
              @release_group.type
            ) %>
          </p>
        </div>
        <div class="relative flex-none">
          <button
            type="button"
            class="-m-2.5 block p-2.5 text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-300"
            aria-expanded="false"
            aria-haspopup="true"
            phx-click={toggle_actions_menu(@release_group.id)}
            phx-click-away={close_actions_menu(@release_group.id)}
          >
            <span class="sr-only"><%= gettext("Open options") %></span>
            <svg
              class="h-5 w-5"
              viewBox="0 0 20 20"
              fill="currentColor"
              aria-hidden="true"
              data-slot="icon"
            >
              <path d="M10 3a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM10 8.5a1.5 1.5 0 1 1 0 3 1.5 1.5 0 0 1 0-3ZM11.5 15.5a1.5 1.5 0 1 0-3 0 1.5 1.5 0 0 0 3 0Z" />
            </svg>
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
              "hidden pointer-events-auto absolute right-0 z-10 mt-2 w-48 origin-top-right rounded-md bg-white dark:bg-zinc-800 py-2 shadow-lg ring-1 ring-gray-900/5 focus:outline-none"
            ]}
            role="menu"
            aria-orientation="vertical"
            aria-labelledby="options-menu-0-button"
            tabindex="-1"
          >
            <.link
              :for={format <- Records.Record.formats()}
              class="block px-3 py-1 text-sm leading-6 text-gray-900 dark:text-zinc-400 hover:bg-gray-50 dark:hover:text-zinc-300 dark:hover:bg-zinc-700"
              role="menuitem"
              tabindex="-1"
              id={"actions-#{@release_group.id}-#{format}-import"}
              phx-click={
                JS.push("import", value: %{id: @release_group.id, format: format}, page_loading: true)
              }
            >
              <%= Records.Record.format_short_label(format) %>
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
    <span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">
      <%= @type %>
    </span>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:release_groups, [])
     |> assign(:form, to_form(%{"mb_query" => ""}))}
  end

  @impl true
  def handle_event("search", %{"mb_query" => mb_query}, socket) do
    {:ok, release_groups} = search(mb_query)

    {:noreply,
     socket
     |> assign(:release_groups, release_groups)
     |> assign(:form, to_form(%{"mb_query" => mb_query}))}
  end

  defp search(""), do: {:ok, []}

  defp search(mb_query) do
    Records.search_release_group(mb_query, limit: 10)
  end

  defp toggle_actions_menu(record_id) do
    JS.toggle(to: "#actions-#{record_id}")
    |> JS.toggle_class("pointer-events-none", to: "#records > li")
  end

  def close_actions_menu(record_id) do
    JS.hide(to: "#actions-#{record_id}")
    |> JS.remove_class("pointer-events-none", to: "#records > li")
  end
end
