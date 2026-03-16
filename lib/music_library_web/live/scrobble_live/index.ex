defmodule MusicLibraryWeb.ScrobbleLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.RecordComponents, only: [type_label: 1, country_label: 1]

  alias MusicBrainz.{Release, ReleaseGroupSearchResult}
  alias MusicLibrary.Records
  alias MusicLibrary.ScrobbleActivity

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_section={@current_section} socket={@socket}>
      <div>
        <header class="gap-6 mb-2">
          <div class="flex items-center justify-between gap-6 mb-2 mt-2">
            <.search_form query={@search_query} />
            <.button :if={!@can_scrobble?} size="sm" href={LastFm.auth_url()}>
              {gettext("Connect your Last.fm account")}
            </.button>
          </div>
        </header>
        <%= if @search_results != [] && @selected_release_group == nil do %>
          <div class="space-y-3">
            <h3 class="text-lg font-semibold text-zinc-900 dark:text-zinc-200">
              {gettext("Release Groups")}
            </h3>
            <ul class={[
              "mt-5 divide-y divide-zinc-100 dark:divide-slate-300/30",
              "max-h-125 overflow-y-auto"
            ]}>
              <li
                :for={release_group <- @search_results}
                phx-click="select_release_group"
                phx-value-release_group_id={release_group.id}
                class="flex justify-between gap-x-6 py-5 hover:bg-zinc-50 dark:hover:bg-zinc-700 cursor-pointer"
              >
                <div class="shrink-0 flex items-center justify-between w-full px-4">
                  <img
                    class="w-20 flex-none rounded-lg mr-4"
                    alt={release_group.title}
                    src={ReleaseGroupSearchResult.thumb_url(release_group)}
                    onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
                  />
                  <div class="min-w-0 flex-auto">
                    <p class="truncate text-sm leading-6 text-zinc-700 dark:text-zinc-400">
                      {release_group.artists}
                    </p>
                    <p class="truncate mt-1 flex font-semibold text-sm sm:text-base leading-5 text-zinc-700 dark:text-zinc-300 text-wrap">
                      {release_group.title}
                    </p>
                    <p class="mt-1 flex items-center gap-1 text-xs leading-5 text-zinc-500 dark:text-zinc-400">
                      {Records.Record.format_release_date(release_group.release_date)}
                      <span>&middot;</span>
                      <.badge variant="soft" size="xs">{type_label(release_group.type)}</.badge>
                    </p>
                  </div>
                </div>
              </li>
            </ul>
          </div>
        <% end %>

        <%= if @selected_release_group && @releases != [] do %>
          <div class="space-y-3">
            <div class="flex items-center gap-2">
              <.button
                variant="ghost"
                size="sm"
                phx-click="clear_selection"
              >
                <.icon name="hero-arrow-left" class="icon" aria-hidden="true" data-slot="icon" />
                {gettext("Back")}
              </.button>
              <h3 class="text-lg font-semibold">
                {gettext("Releases for \"%{title}\"", title: @selected_release_group.title)}
              </h3>
            </div>

            <ul class="divide-y divide-zinc-100 dark:divide-slate-300/30">
              <li :for={release <- @releases}>
                <.link
                  navigate={~p"/scrobble/#{release.id}"}
                  class="flex items-center gap-x-4 py-5 px-4 hover:bg-zinc-50 dark:hover:bg-zinc-700 transition-colors"
                >
                  <img
                    class="w-20 flex-none rounded-lg"
                    alt={release.title}
                    src={Release.thumb_url(release)}
                    onerror={"this.src = '" <> ~p"/images/cover-not-found.png" <> "';"}
                  />
                  <div class="min-w-0 flex-auto">
                    <p class="font-medium text-zinc-900 dark:text-zinc-100">
                      {release.title}
                    </p>
                    <div class="mt-1 flex flex-wrap items-center gap-x-2 gap-y-1 text-sm text-zinc-500 dark:text-zinc-400">
                      <span :if={release.date}>{release.date}</span>
                      <span :if={release.country}>
                        {country_label(release.country)}
                      </span>
                      <.badge :if={release.catalog_number} variant="soft" size="xs">
                        {release.catalog_number}
                      </.badge>
                      <span :if={release.media != []}>
                        {ngettext("1 disc", "%{count} discs", Release.media_count(release))}
                      </span>
                    </div>
                  </div>
                </.link>
              </li>
            </ul>
          </div>
        <% end %>

        <%= if @loading && @search_query != "" do %>
          <div class="text-center py-8">
            <.loading class="size-8 mx-auto text-zinc-400" />
            <p class="text-zinc-600 dark:text-zinc-400 mt-2">
              <%= if @selected_release_group do %>
                {gettext("Loading releases...")}
              <% else %>
                {gettext("Searching...")}
              <% end %>
            </p>
          </div>
        <% end %>

        <%= if @search_query != "" && @search_results == [] && not @loading do %>
          <div class="text-center py-8">
            <.icon
              name="hero-magnifying-glass"
              class="h-12 w-12 mx-auto text-zinc-300 dark:text-zinc-600"
            />
            <p class="text-zinc-600 dark:text-zinc-400 mt-3">
              {gettext("No release groups found for \"%{query}\"", query: @search_query)}
            </p>
            <p class="text-sm text-zinc-500 dark:text-zinc-500 mt-1">
              {gettext("Try a different search term or check the spelling")}
            </p>
          </div>
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
       search_results: [],
       selected_release_group: nil,
       releases: [],
       loading: false,
       can_scrobble?: ScrobbleActivity.can_scrobble?()
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, gettext("Scrobble"))
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    if String.trim(query) == "" do
      {:noreply,
       assign(socket,
         search_query: query,
         search_results: [],
         selected_release_group: nil,
         releases: []
       )}
    else
      send(self(), {:perform_search, query})
      {:noreply, assign(socket, search_query: query, loading: true)}
    end
  end

  def handle_event("select_release_group", %{"release_group_id" => release_group_id}, socket) do
    selected_release_group =
      Enum.find(socket.assigns.search_results, &(&1.id == release_group_id))

    if selected_release_group do
      send(self(), {:fetch_releases, selected_release_group})
      {:noreply, assign(socket, selected_release_group: selected_release_group, loading: true)}
    else
      {:noreply, socket}
    end
  end

  def handle_event("clear_selection", _params, socket) do
    {:noreply, assign(socket, selected_release_group: nil, releases: [])}
  end

  @impl true
  def handle_info({:perform_search, query}, socket) do
    case MusicBrainz.search_release_group(query, limit: 20) do
      {:ok, results} ->
        {:noreply,
         assign(socket,
           search_results: results.release_groups,
           loading: false,
           selected_release_group: nil,
           releases: []
         )}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to search for release groups"))
         |> assign(loading: false)}
    end
  end

  def handle_info({:fetch_releases, release_group}, socket) do
    case MusicBrainz.get_releases(release_group.id, limit: 50) do
      {:ok, %{"releases" => releases}} ->
        releases =
          releases
          |> Enum.map(&MusicBrainz.Release.from_api_response/1)

        {:noreply, assign(socket, releases: releases, loading: false)}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, gettext("Failed to fetch releases for this release group"))
         |> assign(loading: false)}
    end
  end
end
