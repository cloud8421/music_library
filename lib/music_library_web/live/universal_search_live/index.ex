defmodule MusicLibraryWeb.UniversalSearchLive.Index do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.SearchComponents

  alias MusicLibrary.Search
  alias Phoenix.LiveView.ColocatedHook

  def universal_search_trigger(assigns) do
    ~H"""
    <script :type={ColocatedHook} name=".SearchGlobalShortcut">
      export default {
        mounted() {
          const universalSearchButton = document.querySelector("#universal-search-button");

          document.addEventListener("keydown", (event) => {
            switch (event.key) {
              case "k":
                if (event.metaKey || event.ctrlKey) {
                  event.preventDefault();
                  universalSearchButton.click();
                }
                break;
              default:
                break;
            }
          });
        },
      };
    </script>
    <.button
      id="universal-search-button"
      variant="soft"
      title={gettext("Search (Cmd/Ctrl+K)")}
      phx-click="open_modal"
      phx-target="#universal-search"
      phx-hook=".SearchGlobalShortcut"
    >
      <span class="sr-only">{gettext("Search (Cmd/Ctrl+K)")}</span>
      <.icon name="hero-magnifying-glass" class="h-5 w-5" />
    </.button>
    """
  end

  @impl true
  def mount(socket) do
    {:ok,
     socket
     |> assign(:show_modal, false)
     |> reset()}
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
     |> reset()}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    case String.trim(query) do
      "" ->
        {:noreply,
         socket
         |> assign(:search_query, "")
         |> reset()}

      query ->
        search_results = Search.universal_search(query, limit: 5)
        search_counts = Search.search_counts(query)

        total_results =
          length(search_results.collection) +
            length(search_results.wishlist) +
            length(search_results.artists)

        {:noreply,
         socket
         |> assign(:search_query, query)
         |> assign(:search_results, search_results)
         |> assign(:search_counts, search_counts)
         |> assign(:total_results, total_results)}
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

  defp reset(socket) do
    socket
    |> assign(:search_query, "")
    |> assign(:search_results, %{collection: [], wishlist: [], artists: []})
    |> assign(:search_counts, %{collection_count: 0, wishlist_count: 0, artists_count: 0})
    |> assign(:total_results, 0)
  end
end
