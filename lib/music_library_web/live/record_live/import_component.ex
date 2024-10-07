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
      >
        <.input
          id={:mb_query}
          name={:mb_query}
          field={@form[:mb_query]}
          type="text"
          label="Search for a record on MusicBrainz"
          prompt="Search for records"
          phx-debounce="500"
        />
      </.simple_form>
      <ul :if={@release_groups !== []} role="list" class="divide-y divide-gray-100">
        <.result :for={release_group <- @release_groups} release_group={release_group} />
      </ul>
      <div
        :if={@release_groups == []}
        class="flex items-center justify-center h-32 text-sm text-gray-500"
      >
        No results
      </div>
    </div>
    """
  end

  defp result(assigns) do
    ~H"""
    <li
      id={"musicbrainz_" <> @release_group.id}
      class="flex justify-between gap-x-6 py-5 hover:bg-gray-50"
    >
      <div class="flex min-w-0 gap-x-4">
        <div class="min-w-0 flex-auto">
          <p class="text-sm font-semibold leading-6 text-gray-900">
            <.type_badge type={@release_group.type} />
            <%= @release_group.title %>

            <span class="mt-1 text-xs leading-5 text-gray-500">
              <%= @release_group.release %>
            </span>
          </p>
          <p class="mt-1 truncate text-xs leading-5 text-gray-500"><%= @release_group.artists %></p>
        </div>
      </div>

      <div class="shrink-0 sm:flex sm:flex-col sm:items-end">
        <span class="isolate inline-flex rounded-md shadow-sm">
          <button
            :for={format <- Records.Record.formats()}
            phx-click={
              JS.push("import", value: %{id: @release_group.id, format: format}, page_loading: true)
            }
            type="button"
            class="relative -ml-px inline-flex items-center first:rounded-l-md last:rounded-r-md bg-white px-2 sm:px-3 py-1 sm:py-2 text-sm font-semibold text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-10"
          >
            <%= Records.Record.format_short_label(format) %>
          </button>
        </span>
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
end
