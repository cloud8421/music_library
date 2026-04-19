defmodule MusicLibraryWeb.UniversalSearchLive.Index do
  use MusicLibraryWeb, :live_component

  import MusicLibraryWeb.SearchComponents

  alias MusicLibrary.Search
  alias Phoenix.LiveView.ColocatedHook

  @impl true
  def render(assigns) do
    ~H"""
    <div id={@id} phx-hook="UniversalSearchNavigation">
      <.structured_modal
        :if={@show_modal}
        id="universal-search-root"
        open={@show_modal}
        on_close={JS.push("close_modal", value: %{}, target: "#universal-search")}
      >
        <form class="mt-6 text-sm" phx-change="search" phx-submit="search" phx-target={@myself}>
          <div class="relative">
            <.icon
              name="hero-magnifying-glass"
              class="absolute top-1/2 left-3 size-5 -translate-y-1/2 transform text-zinc-400"
            />
            <label for="universal-search-input" class="sr-only">Universal Search</label>
            <.input
              name="query"
              id="universal-search-input"
              placeholder="Search records and artists..."
              value={@search_query}
              phx-debounce="300"
              autofocus
            />
          </div>
        </form>

        <.empty_state :if={@search_query == ""} />

        <.no_results
          :if={@search_query != "" and @total_results == 0}
          query={@search_query}
          target={@myself}
        />

        <div :if={@total_results > 0} class="mt-4 max-h-148 overflow-y-auto md:max-h-164">
          <.search_result_group
            :if={length(@navigation_links_results) > 0}
            title={gettext("Go to")}
            count={length(@navigation_links_results)}
          >
            <.search_result_navigation
              :for={link <- @navigation_links_results}
              label={link.label}
              icon={link.icon}
              phx-click="navigate_to_link"
              phx-value-path={link.path}
              phx-target={@myself}
            />
          </.search_result_group>
          <.search_result_group
            :if={length(@search_results.artists) > 0}
            title="Artists"
            count={length(@search_results.artists)}
            total_count={@search_counts.artists_count}
          >
            <.search_result_artist
              :for={%{artist: artist, image_data_hash: image_data_hash} <- @search_results.artists}
              artist={artist}
              image_data_hash={image_data_hash}
              phx-click="navigate_to_artist"
              phx-value-id={artist.musicbrainz_id}
              phx-target={@myself}
            />
          </.search_result_group>
        </div>
        <.search_result_group
          :if={length(@search_results.collection) > 0}
          title="Collection"
          count={length(@search_results.collection)}
          total_count={@search_counts.collection_count}
        >
          <.search_result_record
            :for={record <- @search_results.collection}
            record={record}
            type={:collection}
            phx-click="navigate_to_record"
            phx-value-id={record.id}
            phx-value-type="collection"
            phx-target={@myself}
          />
          <:actions>
            <.view_all_button
              :if={@search_counts.collection_count > length(@search_results.collection)}
              count={@search_counts.collection_count}
              target="collection"
              phx-click="navigate_to_collection"
              phx-value-query={@search_query}
              phx-target={@myself}
            />
          </:actions>
        </.search_result_group>
        <.search_result_group
          :if={length(@search_results.wishlist) > 0}
          title="Wishlist"
          count={length(@search_results.wishlist)}
          total_count={@search_counts.wishlist_count}
        >
          <.search_result_record
            :for={record <- @search_results.wishlist}
            record={record}
            type={:wishlist}
            phx-click="navigate_to_record"
            phx-value-id={record.id}
            phx-value-type="wishlist"
            phx-target={@myself}
          />
          <:actions>
            <.view_all_button
              :if={@search_counts.wishlist_count > length(@search_results.wishlist)}
              count={@search_counts.wishlist_count}
              target="wishlist"
              phx-click="navigate_to_wishlist"
              phx-value-query={@search_query}
              phx-target={@myself}
            />
          </:actions>
        </.search_result_group>
        <.search_result_group
          :if={length(@search_results.record_sets) > 0}
          title="Record Sets"
          count={length(@search_results.record_sets)}
          total_count={@search_counts.record_sets_count}
        >
          <.search_result_record_set
            :for={record_set <- @search_results.record_sets}
            record_set={record_set}
            phx-click="navigate_to_record_set"
            phx-value-id={record_set.id}
            phx-target={@myself}
          />
          <:actions>
            <.view_all_button
              :if={@search_counts.record_sets_count > length(@search_results.record_sets)}
              count={@search_counts.record_sets_count}
              target="record set"
              phx-click="navigate_to_record_sets"
              phx-value-query={@search_query}
              phx-target={@myself}
            />
          </:actions>
        </.search_result_group>
        <.results_footer
          total_results={@total_results}
          has_navigable_items={@search_query != ""}
        />
      </.structured_modal>
    </div>
    """
  end

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
      <.icon name="hero-magnifying-glass" class="icon" />
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
        navigation_links_results = filter_navigation_links(query)

        total_results =
          length(navigation_links_results) +
            length(search_results.collection) +
            length(search_results.wishlist) +
            length(search_results.artists) +
            length(search_results.record_sets)

        {:noreply,
         socket
         |> assign(:search_query, query)
         |> assign(:search_results, search_results)
         |> assign(:search_counts, search_counts)
         |> assign(:navigation_links_results, navigation_links_results)
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

  @impl true
  def handle_event("navigate_to_record_set", %{"id" => id}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> push_navigate(to: ~p"/record-sets/#{id}")}
  end

  @impl true
  def handle_event("navigate_to_record_sets", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> push_navigate(to: ~p"/record-sets?query=#{query}")}
  end

  @impl true
  def handle_event("navigate_to_link", %{"path" => path}, socket) do
    {:noreply,
     socket
     |> assign(:show_modal, false)
     |> push_navigate(to: path)}
  end

  defp reset(socket) do
    socket
    |> assign(:search_query, "")
    |> assign(:search_results, %{collection: [], wishlist: [], artists: [], record_sets: []})
    |> assign(:search_counts, %{
      collection_count: 0,
      wishlist_count: 0,
      artists_count: 0,
      record_sets_count: 0
    })
    |> assign(:navigation_links_results, [])
    |> assign(:total_results, 0)
  end

  defp filter_navigation_links(query) do
    downcased = String.downcase(query)

    Enum.filter(navigation_links(), fn link ->
      String.contains?(String.downcase(link.label), downcased) or
        Enum.any?(link.keywords, &String.contains?(&1, downcased))
    end)
  end

  defp navigation_links do
    [
      %{
        label: "Stats",
        path: ~p"/",
        icon: "hero-chart-pie",
        keywords: ["stats", "dashboard", "home"]
      },
      %{
        label: "Collection",
        path: ~p"/collection",
        icon: "hero-circle-stack",
        keywords: ["collection", "collected", "records"]
      },
      %{
        label: "Collection Chat",
        path: ~p"/collection?chat=open",
        icon: "hero-chat-bubble-left-right",
        keywords: ["chat", "collection", "ask", "ai"]
      },
      %{
        label: "Wishlist",
        path: ~p"/wishlist",
        icon: "hero-star",
        keywords: ["wishlist", "wish", "want"]
      },
      %{
        label: "Sets",
        path: ~p"/record-sets",
        icon: "hero-rectangle-stack",
        keywords: ["sets", "record sets", "groups"]
      },
      %{
        label: "Scrobble Anything",
        path: ~p"/scrobble",
        icon: "hero-play",
        keywords: ["scrobble", "play"]
      },
      %{
        label: "Scrobbled Tracks",
        path: ~p"/scrobbled-tracks",
        icon: "hero-musical-note",
        keywords: ["scrobbled", "tracks", "history", "listening"]
      },
      %{
        label: "Scrobble Rules",
        path: ~p"/scrobble-rules",
        icon: "hero-adjustments-horizontal",
        keywords: ["scrobble rules", "rules", "remap"]
      },
      %{
        label: "Online Store Templates",
        path: ~p"/online-store-templates",
        icon: "hero-building-storefront",
        keywords: ["store", "templates", "online", "buy"]
      },
      %{
        label: "Live Dashboard",
        path: ~p"/dev/dashboard",
        icon: "hero-chart-bar",
        keywords: ["live dashboard", "telemetry", "metrics"]
      },
      %{
        label: "Oban",
        path: ~p"/dev/oban",
        icon: "hero-cog",
        keywords: ["oban", "jobs", "workers", "queue"]
      },
      %{
        label: "Errors",
        path: ~p"/dev/errors",
        icon: "hero-bug-ant",
        keywords: ["errors", "error tracker", "exceptions", "bugs"]
      },
      %{
        label: "Maintenance",
        path: ~p"/maintenance",
        icon: "hero-wrench-screwdriver",
        keywords: ["maintenance", "admin", "vacuum"]
      }
    ]
  end
end
