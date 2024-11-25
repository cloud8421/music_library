defmodule MusicLibraryWeb.Telemetry do
  use Supervisor
  import Telemetry.Metrics

  def start_link(arg) do
    Supervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  @impl true
  def init(_arg) do
    children = [
      {MusicLibraryWeb.Telemetry.Storage, metrics()},
      # Telemetry poller will execute the given period measurements
      # every 10_000ms. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 10_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Phoenix Metrics
      summary("phoenix.endpoint.start.system_time",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.endpoint.stop.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.start.system_time",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.exception.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.router_dispatch.stop.duration",
        tags: [:route],
        unit: {:native, :millisecond}
      ),
      summary("phoenix.socket_connected.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_joined.duration",
        unit: {:native, :millisecond}
      ),
      summary("phoenix.channel_handled_in.duration",
        tags: [:event],
        unit: {:native, :millisecond}
      ),

      # Database Metrics
      summary("music_library.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements"
      ),
      summary("music_library.repo.query.decode_time",
        unit: {:native, :millisecond},
        description: "The time spent decoding the data received from the database"
      ),
      summary("music_library.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query"
      ),
      summary("music_library.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection"
      ),
      summary("music_library.repo.query.idle_time",
        unit: {:native, :millisecond},
        description:
          "The time the connection spent waiting before being checked out for the query"
      ),

      # LastFm HTTP Metrics
      summary("finch.request.stop.duration",
        unit: {:native, :millisecond},
        tags: [:normalized_path],
        tag_values: &add_normalized_path/1,
        keep: &keep_last_fm/1,
        reporter_options: [
          nav: "HTTP - Last.fm"
        ]
      ),
      summary("finch.response.stop.duration",
        unit: {:native, :millisecond},
        tags: [:normalized_path],
        tag_values: &add_normalized_path/1,
        keep: &keep_last_fm/1,
        reporter_options: [
          nav: "HTTP - Last.fm"
        ]
      ),

      # MusicBrainz HTTP Metrics
      summary("finch.request.start.duration",
        unit: {:native, :millisecond},
        tags: [:normalized_path],
        tag_values: &add_normalized_path/1,
        keep: &keep_musicbrainz/1,
        reporter_options: [
          nav: "HTTP - MusicBrainz"
        ]
      ),
      summary("finch.response.stop.duration",
        unit: {:native, :millisecond},
        tags: [:normalized_path],
        tag_values: &add_normalized_path/1,
        keep: &keep_musicbrainz/1,
        reporter_options: [
          nav: "HTTP - MusicBrainz"
        ]
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :kilobyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {MusicLibraryWeb, :count_users, []}
    ]
  end

  defp add_normalized_path(metadata) do
    Map.put(metadata, :normalized_path, URI.parse(metadata.request.path).path)
  end

  defp keep_last_fm(metadata) do
    metadata.request.host == "ws.audioscrobbler.com"
  end

  defp keep_musicbrainz(metadata) do
    metadata.request.host == "musicbrainz.org"
  end
end
