defmodule MusicLibraryWeb.RecordLive.ImportComponent do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Records

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.simple_form
        for={@form}
        id="search-form"
        phx-target={@myself}
        phx-change="search"
        phx-submit="search"
      >
        <.input
          field={@form[:query]}
          type="text"
          label="Search for a record on MusicBrainz"
          prompt="Search for records"
          phx-debounce="500"
        />
      </.simple_form>
      <ul role="list" class="divide-y divide-gray-100">
        <.result :for={release_group <- @release_groups} release_group={release_group} />
      </ul>
    </div>
    """
  end

  defp result(assigns) do
    ~H"""
    <li
      class="flex justify-between gap-x-6 py-5 cursor-pointer hover:bg-gray-50"
      phx-click={JS.push("import", value: %{id: @release_group.id}, page_loading: true)}
    >
      <div class="flex min-w-0 gap-x-4">
        <div class="min-w-0 flex-auto">
          <p class="text-sm font-semibold leading-6 text-gray-900">
            <.type_badge type={@release_group.type} />
            <%= @release_group.title %>

            <span class="mt-1 text-xs leading-5 text-gray-500">
              <%= @release_group.year %>
            </span>
          </p>
          <p class="mt-1 truncate text-xs leading-5 text-gray-500"><%= @release_group.artists %></p>
        </div>
      </div>

      <div class="hidden shrink-0 sm:flex sm:flex-col sm:items-end">
        <span class="isolate inline-flex rounded-md shadow-sm">
          <button
            :for={format <- Records.Record.formats()}
            phx-click={JS.push("import", value: %{id: @release_group.id, format: format})}
            type="button"
            class="relative -ml-px inline-flex items-center first:rounded-l-md last:rounded-r-md bg-white px-3 py-2 text-sm font-semibold text-gray-900 ring-1 ring-inset ring-gray-300 hover:bg-gray-50 focus:z-10"
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
     |> assign(:form, to_form(%{"query" => ""}))}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:ok, release_groups} = search(query)

    {:noreply,
     socket
     |> assign(:release_groups, release_groups)
     |> assign(:form, to_form(%{"query" => query}))}
  end

  defp search(""), do: {:ok, []}

  defp search(query) do
    case Records.search_release_group(query, limit: 10) do
      {:ok, result} ->
        {:ok,
         Enum.map(result["release-groups"], fn rg ->
           %{
             id: rg["id"],
             type: parse_subtype(rg["primary-type"]),
             title: rg["title"],
             artists:
               rg["artist-credit"]
               |> Enum.map(fn ac -> ac["artist"]["name"] end)
               |> Enum.join(", "),
             year: parse_year(rg["first-release-date"])
           }
         end)}

      error ->
        error
    end
  end

  defp parse_year(nil), do: ""

  defp parse_year(iso_date) do
    case Date.from_iso8601(iso_date) do
      {:ok, date} -> date.year
      _error -> nil
    end
  end

  defp parse_subtype("Album"), do: :album
  defp parse_subtype("EP"), do: :ep
  defp parse_subtype("Live"), do: :live
  defp parse_subtype("Compilation"), do: :compilation
  defp parse_subtype("Single"), do: :single
  defp parse_subtype(_), do: :other
end
