defmodule MusicLibraryWeb.RecordSetLive.RecordPicker do
  use MusicLibraryWeb, :live_component

  alias MusicLibrary.Collection
  alias MusicLibrary.Records.Record
  alias MusicLibrary.Wishlist

  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div id="record-picker-navigation" phx-hook="RecordPickerNavigation">
      <header class="mb-6">
        <h1 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
          {@title}
        </h1>
        <p class="text-sm text-zinc-500 dark:text-zinc-400 mt-1">
          {gettext("Search your records to add a record to this set.")}
        </p>
      </header>
      <form
        class="w-full sm:w-1/3"
        for={@query}
        phx-submit="search"
        phx-change="search"
        phx-target={@myself}
      >
        <.input
          type="search"
          size="sm"
          id="record-picker-search-input"
          name={:query}
          value={@query}
          placeholder={gettext("Search")}
          phx-debounce="500"
          autocomplete="off"
          autofocus
        />
      </form>

      <div
        :if={@query != ""}
        class="mt-4 max-h-96 overflow-y-auto"
      >
        <p
          :if={@collected_results == [] and @wishlisted_results == []}
          class="py-4 text-center text-sm text-zinc-500 dark:text-zinc-400"
        >
          {gettext("No records found")}
        </p>

        <div :if={@collected_results != []}>
          <h3 class="text-xs font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-400 mb-1">
            {gettext("Collected")}
          </h3>
          <ul class="divide-y divide-zinc-100 dark:divide-zinc-700">
            <.record_result :for={record <- @collected_results} record={record} myself={@myself} />
          </ul>
        </div>

        <div :if={@wishlisted_results != []} class={[@collected_results != [] && "mt-4"]}>
          <h3 class="text-xs font-medium uppercase tracking-wide text-zinc-500 dark:text-zinc-400 mb-1">
            {gettext("Wishlisted")}
          </h3>
          <ul class="divide-y divide-zinc-100 dark:divide-zinc-700">
            <.record_result :for={record <- @wishlisted_results} record={record} myself={@myself} />
          </ul>
        </div>
      </div>
    </div>
    """
  end

  defp record_result(assigns) do
    ~H"""
    <li
      role="option"
      class={[
        "flex items-center gap-3 py-3 px-2 hover:bg-zinc-50 dark:hover:bg-zinc-800 cursor-pointer rounded-lg",
        "aria-selected:bg-zinc-100 dark:aria-selected:bg-zinc-700"
      ]}
      phx-click="add_record"
      phx-target={@myself}
      phx-value-record-id={@record.id}
    >
      <div class="w-12 flex-none">
        <MusicLibraryWeb.RecordComponents.record_cover
          record={@record}
          class="rounded aspect-square object-cover"
          width={96}
        />
      </div>
      <div class="min-w-0 flex-auto">
        <p class="text-sm font-medium text-zinc-900 dark:text-zinc-100 truncate">
          {@record.title}
        </p>
        <p class="text-xs text-zinc-500 dark:text-zinc-400 truncate">
          {Record.artist_names(@record)}
        </p>
        <p class="mt-1 text-xs leading-5 text-zinc-500 dark:text-zinc-400">
          {Record.format_release_date(@record.release_date)} · {type_label(@record.type)} · {format_label(
            @record.format
          )}
        </p>
      </div>
      <div class="flex-none">
        <.icon
          name="hero-plus-circle"
          class="h-5 w-5 text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-300"
          aria-hidden="true"
          data-slot="icon"
        />
      </div>
    </li>
    """
  end

  @impl true
  def update(assigns, socket) do
    existing_record_ids =
      MapSet.new(assigns.record_set.items, fn item -> item.record.id end)

    {:ok,
     socket
     |> assign(assigns)
     |> assign(:query, "")
     |> assign(:collected_results, [])
     |> assign(:wishlisted_results, [])
     |> assign(:existing_record_ids, existing_record_ids)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {collected, wishlisted} =
      if String.trim(query) == "" do
        {[], []}
      else
        reject = fn record ->
          MapSet.member?(socket.assigns.existing_record_ids, record.id)
        end

        collected =
          query
          |> Collection.search_records(limit: 20)
          |> Enum.reject(reject)

        wishlisted =
          query
          |> Wishlist.search_records(limit: 20)
          |> Enum.reject(reject)

        {collected, wishlisted}
      end

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:collected_results, collected)
     |> assign(:wishlisted_results, wishlisted)}
  end

  def handle_event("add_record", %{"record-id" => record_id}, socket) do
    record_set = socket.assigns.record_set

    case MusicLibrary.RecordSets.add_record_to_set(record_set, record_id) do
      {:ok, updated_set} ->
        existing_record_ids = MapSet.put(socket.assigns.existing_record_ids, record_id)

        reject = fn record -> record.id == record_id end

        collected_results = Enum.reject(socket.assigns.collected_results, reject)
        wishlisted_results = Enum.reject(socket.assigns.wishlisted_results, reject)

        notify_parent({:added, updated_set})
        put_toast!(:info, gettext("Record added to set"))

        {:noreply,
         socket
         |> assign(:record_set, updated_set)
         |> assign(:existing_record_ids, existing_record_ids)
         |> assign(:collected_results, collected_results)
         |> assign(:wishlisted_results, wishlisted_results)}

      {:error, _changeset} ->
        put_toast!(:error, gettext("Could not add record to set"))
        {:noreply, socket}
    end
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
