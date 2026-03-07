alias MusicLibrary.RecordSets
alias MusicLibraryWeb.RecordSetLive
alias Phoenix.LiveView.LiveStream

Logger.configure(level: :error)

# --- Data loading ---

default_query = ""
default_order = :updated_at
default_page_size = 20

total_sets = RecordSets.count_record_sets(default_query)

sets =
  RecordSets.search_record_sets(default_query,
    offset: 0,
    limit: default_page_size,
    order: default_order
  )

# --- Assigns construction ---

list_params = %{
  page: 1,
  page_size: default_page_size,
  query: default_query,
  order: default_order,
  total_entries: total_sets,
  total_pages: max(ceil(total_sets / default_page_size), 1)
}

empty_list_params = %{list_params | total_entries: 0, total_pages: 1}

stream = LiveStream.new(:record_sets, "0", sets, [])
empty_stream = LiveStream.new(:record_sets, "0", [], [])

base_assigns = %{
  __changed__: nil,
  flash: %{},
  current_section: :record_sets,
  live_action: :index,
  record_set: nil,
  socket: %Phoenix.LiveView.Socket{
    endpoint: MusicLibraryWeb.Endpoint,
    router: MusicLibraryWeb.Router
  }
}

assigns_with_data = Map.merge(base_assigns, %{list_params: list_params, streams: %{record_sets: stream}})
assigns_empty = Map.merge(base_assigns, %{list_params: empty_list_params, streams: %{record_sets: empty_stream}})

# --- Benchmark ---

Benchee.run(
  %{
    "data loading (count + search)" =>
      fn ->
        total = RecordSets.count_record_sets(default_query)

        RecordSets.search_record_sets(default_query,
          offset: 0,
          limit: default_page_size,
          order: default_order
        )

        total
      end,
    "render/1 (default page, #{length(sets)} sets)" =>
      fn -> RecordSetLive.Index.render(assigns_with_data) end,
    "render/1 (empty)" =>
      fn -> RecordSetLive.Index.render(assigns_empty) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)
