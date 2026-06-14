defmodule MusicLibraryWeb.ScrobbleLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.RecordComponents, only: [type_label: 1]

  alias MusicBrainz.ReleaseGroupSearchResult
  alias MusicLibrary.Records
  alias MusicLibrary.ScrobbleActivity
  alias Phoenix.LiveView.AsyncResult

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_section={@current_section}
      socket={@socket}
      toasts_sync={assigns[:toasts_sync]}
    >
      <div>
        <header class="mb-2 gap-6">
          <div class="my-2 flex items-center justify-between gap-6">
            <.search_form query={@search_query} />
            <.button :if={!@can_scrobble?} size="sm" href={LastFm.auth_url()}>
              {gettext("Connect your Last.fm account")}
            </.button>
          </div>
        </header>
        <%= if @search_query != "" do %>
          <.async_result :let={result} assign={@search}>
            <:loading>
              <div class="py-8 text-center">
                <.loading class="mx-auto size-8 text-zinc-400" />
                <p class="mt-2 text-zinc-600 dark:text-zinc-400">
                  {gettext("Searching...")}
                </p>
              </div>
            </:loading>
            <:failed :let={_reason}>
              <div class="py-8 text-center">
                <.icon
                  name="hero-exclamation-triangle"
                  class="mx-auto size-12 text-red-300 dark:text-red-600"
                />
                <p class="mt-3 text-zinc-600 dark:text-zinc-400">
                  {gettext("Failed to search for release groups")}
                </p>
              </div>
            </:failed>
            <%= if result.release_groups != [] do %>
              <div class="space-y-3">
                <h3 class="text-lg font-semibold text-zinc-900 dark:text-zinc-200">
                  {gettext("Release Groups")}
                </h3>
                <ul class={[
                  "mt-5 divide-y divide-zinc-100 dark:divide-slate-300/30",
                  "max-h-125 overflow-y-auto"
                ]}>
                  <li :for={release_group <- result.release_groups}>
                    <.link
                      navigate={~p"/scrobble/#{release_group.id}"}
                      class="flex cursor-pointer justify-between gap-x-6 py-5 hover:bg-zinc-100 dark:hover:bg-zinc-700"
                    >
                      <div class="flex w-full shrink-0 items-center justify-between px-4">
                        <img
                          class="mr-4 w-20 flex-none rounded-lg"
                          alt={release_group.title}
                          src={ReleaseGroupSearchResult.thumb_url(release_group)}
                          onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
                        />
                        <div class="min-w-0 flex-auto">
                          <p class="truncate text-sm/6 text-zinc-700 dark:text-zinc-400">
                            {release_group.artists}
                          </p>
                          <p class="mt-1 flex truncate text-sm/5 font-semibold text-wrap text-zinc-700 sm:text-base dark:text-zinc-300">
                            {release_group.title}
                          </p>
                          <p class="mt-1 flex items-center gap-1 text-xs/5 text-zinc-500 dark:text-zinc-400">
                            {Records.Record.format_release_date(release_group.release_date)}
                            <span>&middot;</span>
                            <.badge variant="soft" size="xs">{type_label(release_group.type)}</.badge>
                          </p>
                        </div>
                      </div>
                    </.link>
                  </li>
                </ul>
              </div>
            <% else %>
              <div class="py-8 text-center">
                <.icon
                  name="hero-magnifying-glass"
                  class="mx-auto size-12 text-zinc-300 dark:text-zinc-600"
                />
                <p class="mt-3 text-zinc-600 dark:text-zinc-400">
                  {gettext("No release groups found for \"%{query}\"", query: @search_query)}
                </p>
                <p class="mt-1 text-sm text-zinc-500 dark:text-zinc-500">
                  {gettext("Try a different search term or check the spelling")}
                </p>
              </div>
            <% end %>
          </.async_result>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       current_section: :scrobble,
       search_query: "",
       search: AsyncResult.loading(),
       can_scrobble?: ScrobbleActivity.can_scrobble?()
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, params) do
    query = params["query"] || ""

    socket
    |> assign(:page_title, gettext("Scrobble Anything"))
    |> run_search(query)
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply, run_search(socket, query)}
  end

  @impl true
  def handle_async({:search, query}, {:ok, {:ok, results}}, socket) do
    if current_search?(socket, query) do
      {:noreply,
       assign(
         socket,
         :search,
         AsyncResult.ok(socket.assigns.search, results)
       )}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:search, query}, {:ok, {:error, _reason}}, socket) do
    if current_search?(socket, query) do
      {:noreply, search_failed(socket)}
    else
      {:noreply, socket}
    end
  end

  def handle_async({:search, query}, {:exit, _reason}, socket) do
    if current_search?(socket, query) do
      {:noreply, search_failed(socket)}
    else
      {:noreply, socket}
    end
  end

  defp run_search(socket, query) do
    if String.trim(query) == "" do
      assign(socket,
        search_query: query,
        search: AsyncResult.loading()
      )
    else
      socket
      |> assign(search_query: query)
      |> start_async({:search, query}, fn ->
        MusicBrainz.search_release_group(query, limit: 20)
      end)
    end
  end

  defp current_search?(socket, query), do: socket.assigns.search_query == query

  defp search_failed(socket) do
    socket
    |> put_flash(:error, gettext("Failed to search for release groups"))
    |> assign(:search, AsyncResult.failed(socket.assigns.search, {:error, :search_failed}))
  end
end
