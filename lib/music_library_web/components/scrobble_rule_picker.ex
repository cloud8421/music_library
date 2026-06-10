defmodule MusicLibraryWeb.ScrobbleRulePicker do
  @moduledoc false
  use MusicLibraryWeb, :live_component

  require Logger

  alias MusicLibrary.Collection
  alias MusicLibrary.Records.Record
  alias MusicLibrary.ScrobbleRules
  alias MusicLibrary.Wishlist

  import MusicLibraryWeb.RecordComponents,
    only: [format_label: 1, type_label: 1, release_status_tooltip: 1]

  @impl true
  def render(assigns) do
    ~H"""
    <div id="rule-picker-navigation" phx-hook="RulePickerNavigation">
      <header class="mb-6">
        <h1 class="text-lg font-semibold text-zinc-900 dark:text-zinc-100">
          {gettext("Create Scrobble Rule")}
        </h1>
        <p class="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
          {gettext("Search your records to map \"%{album_title}\" to a release.",
            album_title: @album_title
          )}
        </p>
      </header>
      <form
        id="rule-picker-search-form"
        class="w-full"
        for={@query}
        phx-submit="search"
        phx-change="search"
        phx-target={@myself}
      >
        <.input
          type="search"
          size="sm"
          id="rule-picker-search-input"
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
          <h3 class="mb-1 text-xs font-medium tracking-wide text-zinc-500 uppercase dark:text-zinc-400">
            {gettext("Collected")}
          </h3>
          <ul class="divide-y divide-zinc-100 dark:divide-zinc-700">
            <.record_result
              :for={record <- @collected_results}
              record={record}
              myself={@myself}
            />
          </ul>
        </div>

        <div :if={@wishlisted_results != []} class={[@collected_results != [] && "mt-4"]}>
          <h3 class="mb-1 text-xs font-medium tracking-wide text-zinc-500 uppercase dark:text-zinc-400">
            {gettext("Wishlisted")}
          </h3>
          <ul class="divide-y divide-zinc-100 dark:divide-zinc-700">
            <.record_result
              :for={record <- @wishlisted_results}
              record={record}
              myself={@myself}
            />
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
        "flex cursor-pointer items-center gap-3 rounded-lg px-2 py-3 hover:bg-zinc-100 dark:hover:bg-zinc-800",
        "aria-selected:bg-zinc-100 dark:aria-selected:bg-zinc-700"
      ]}
      phx-click="select_record"
      phx-target={@myself}
      phx-value-record-id={@record.id}
      phx-value-selected-release-id={@record.selected_release_id}
    >
      <div class="w-12 flex-none">
        <MusicLibraryWeb.RecordComponents.record_cover
          record={@record}
          class="aspect-square rounded object-cover"
          width={96}
        />
      </div>
      <div class="min-w-0 flex-auto">
        <p class="truncate text-sm font-medium text-zinc-900 dark:text-zinc-100">
          {@record.title}
        </p>
        <p class="truncate text-xs text-zinc-500 dark:text-zinc-400">
          {Record.artist_names(@record)}
        </p>
        <p class="mt-1 flex items-center gap-1 text-xs/5 text-zinc-500 dark:text-zinc-400">
          <.release_status_tooltip record={@record} />
          {Record.format_release_date(@record.release_date)} · {format_label(@record.format)} · {type_label(
            @record.type
          )}
        </p>
      </div>
      <div class="flex-none">
        <.icon
          name="hero-link"
          class="size-5 text-zinc-400 hover:text-zinc-600 dark:hover:text-zinc-300"
          aria-hidden="true"
          data-slot="icon"
        />
      </div>
    </li>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign_new(:query, fn -> "" end)
     |> assign_new(:collected_results, fn -> [] end)
     |> assign_new(:wishlisted_results, fn -> [] end)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {collected, wishlisted} =
      if String.trim(query) == "" do
        {[], []}
      else
        collected =
          query
          |> Collection.search_records(limit: 20)
          |> Enum.filter(&has_selected_release?/1)

        wishlisted =
          query
          |> Wishlist.search_records(limit: 20)
          |> Enum.filter(&has_selected_release?/1)

        {collected, wishlisted}
      end

    {:noreply,
     socket
     |> assign(:query, query)
     |> assign(:collected_results, collected)
     |> assign(:wishlisted_results, wishlisted)}
  end

  @impl true
  def handle_event(
        "select_record",
        %{"record-id" => _record_id, "selected-release-id" => selected_release_id},
        socket
      ) do
    album_title = socket.assigns.album_title

    case ScrobbleRules.create_scrobble_rule(%{
           type: :album,
           match_value: album_title,
           target_musicbrainz_id: selected_release_id
         }) do
      {:ok, rule} ->
        case ScrobbleRules.apply_rule(rule) do
          {:ok, _count} -> :ok
          {:error, reason} -> Logger.warning("Failed to apply scrobble rule: #{inspect(reason)}")
        end

        notify_parent({:rule_created, rule})
        put_toast!(:info, gettext("Scrobble rule created"))
        {:noreply, socket}

      {:error, %Ecto.Changeset{} = changeset} ->
        message =
          if Keyword.has_key?(changeset.errors, :match_value) do
            gettext("A rule for this album already exists")
          else
            gettext("Could not create scrobble rule")
          end

        put_toast!(:error, message)
        {:noreply, socket}
    end
  end

  defp has_selected_release?(record) do
    record.selected_release_id not in [nil, ""]
  end

  defp notify_parent(msg), do: send(self(), {__MODULE__, msg})
end
