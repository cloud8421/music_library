defmodule MusicLibraryWeb.ScrobbleLive.Index do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.ScrobbleActivity

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
       can_scrobble: ScrobbleActivity.can_scrobble?()
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Scrobble")
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
         |> put_flash(:error, "Failed to search for release groups")
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
         |> put_flash(:error, "Failed to fetch releases for this release group")
         |> assign(loading: false)}
    end
  end
end
