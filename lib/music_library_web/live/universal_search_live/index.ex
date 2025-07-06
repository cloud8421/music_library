defmodule MusicLibraryWeb.UniversalSearchLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.SearchComponents

  alias MusicLibrary.Search

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:search_query, "")
     |> assign(:search_results, %{collection: [], wishlist: [], artists: []})
     |> assign(:search_counts, %{collection_count: 0, wishlist_count: 0, artists_count: 0})
     |> assign(:show_modal, false)
     |> assign(:loading, false)
     |> assign(:total_results, 0)}
  end

  @impl true
  def handle_event("open_modal", _params, socket) do
    {:noreply, assign(socket, :show_modal, true)}
  end

  @impl true
  def handle_event("close_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> assign(:search_query, "")
     |> assign(:search_results, %{collection: [], wishlist: [], artists: []})
     |> assign(:search_counts, %{collection_count: 0, wishlist_count: 0, artists_count: 0})
     |> assign(:total_results, 0)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    socket = assign(socket, :search_query, query)

    case String.trim(query) do
      "" ->
        {:noreply,
         socket
         |> assign(:search_results, %{collection: [], wishlist: [], artists: []})
         |> assign(:search_counts, %{collection_count: 0, wishlist_count: 0, artists_count: 0})
         |> assign(:loading, false)
         |> assign(:total_results, 0)}

      _query ->
        send(self(), {:perform_search, query})
        {:noreply, assign(socket, :loading, true)}
    end
  end

  @impl true
  def handle_event("search", params, socket) when is_map(params) do
    query = get_in(params, ["query"]) || ""
    handle_event("search", %{"query" => query}, socket)
  end

  @impl true
  def handle_event("navigate_to_record", %{"id" => id, "type" => "collection"}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> push_navigate(to: ~p"/collection/#{id}")}
  end

  @impl true
  def handle_event("navigate_to_record", %{"id" => id, "type" => "wishlist"}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> push_navigate(to: ~p"/wishlist/#{id}")}
  end

  @impl true
  def handle_event("navigate_to_record", %{"id" => id}, socket) do
    # Default to collection if type not specified
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> push_navigate(to: ~p"/collection/#{id}")}
  end

  @impl true
  def handle_event("navigate_to_artist", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> push_navigate(to: ~p"/artists/#{id}")}
  end

  @impl true
  def handle_event("navigate_to_collection", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> push_navigate(to: ~p"/collection?query=#{query}")}
  end

  @impl true
  def handle_event("navigate_to_wishlist", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> push_navigate(to: ~p"/wishlist?query=#{query}")}
  end

  @impl true
  def handle_info({:perform_search, query}, socket) do
    # Only search if the query hasn't changed (debouncing)
    if query == socket.assigns.search_query do
      search_results = Search.universal_search(query, limit: 5)
      search_counts = Search.search_counts(query)

      total_results =
        length(search_results.collection) +
          length(search_results.wishlist) +
          length(search_results.artists)

      {:noreply,
       socket
       |> assign(:search_results, search_results)
       |> assign(:search_counts, search_counts)
       |> assign(:loading, false)
       |> assign(:total_results, total_results)}
    else
      {:noreply, socket}
    end
  end
end
