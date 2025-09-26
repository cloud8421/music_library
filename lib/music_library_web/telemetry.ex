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
      # every 30 seconds. Learn more here: https://hexdocs.pm/telemetry_metrics
      {:telemetry_poller, measurements: periodic_measurements(), period: 30_000}
      # Add reporters as children of your supervision tree.
      # {Telemetry.Metrics.ConsoleReporter, metrics: metrics()}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end

  def metrics do
    [
      # Database Metrics
      summary("music_library.repo.query.total_time",
        unit: {:native, :millisecond},
        description: "The sum of the other measurements",
        reporter_options: [
          nav: "Repo"
        ],
        tags: [:source]
      ),
      summary("music_library.repo.query.query_time",
        unit: {:native, :millisecond},
        description: "The time spent executing the query",
        reporter_options: [
          nav: "Repo"
        ],
        tags: [:source]
      ),
      summary("music_library.repo.query.queue_time",
        unit: {:native, :millisecond},
        description: "The time spent waiting for a database connection",
        reporter_options: [
          nav: "Repo"
        ],
        tags: [:source]
      ),

      # Oban
      summary("oban.job.stop.duration",
        unit: {:native, :millisecond},
        tags: [:state],
        reporter_options: [
          nav: "Oban"
        ]
      ),

      # HTTP Metrics
      summary("finch.request.stop.duration",
        unit: {:native, :millisecond},
        tags: [:normalized_path],
        tag_values: &add_tags/1,
        drop: &drop_archive_requests/1,
        reporter_options: [
          nav: "External APIs"
        ]
      ),
      summary("finch.request.stop.duration",
        unit: {:native, :millisecond},
        tags: [:host],
        tag_values: &add_tags/1,
        drop: &drop_archive_requests/1,
        reporter_options: [
          nav: "External APIs"
        ]
      ),

      # Assets
      summary("music_library.assets.cache_size",
        unit: {:byte, :kilobyte},
        reporter_options: [nav: "Assets"]
      ),
      summary("music_library.assets.content_size",
        unit: {:byte, :megabyte},
        reporter_options: [nav: "Assets"]
      ),

      # VM Metrics
      summary("vm.memory.total", unit: {:byte, :megabyte}),
      summary("vm.total_run_queue_lengths.total"),
      summary("vm.total_run_queue_lengths.cpu"),
      summary("vm.total_run_queue_lengths.io")
    ]
  end

  defp periodic_measurements do
    [
      {MusicLibrary.Assets, :track_total_cache_size, []},
      {MusicLibrary.Assets, :track_total_content_size, []}
      # A module, function and arguments to be invoked periodically.
      # This function must call :telemetry.execute/3 and a metric must be added above.
      # {MusicLibraryWeb, :count_users, []}
    ]
  end

  defp add_tags(metadata) do
    req = metadata.request

    Map.merge(metadata, %{
      host: req.host,
      normalized_path: URI.parse(req.path).path
    })
  end

  defp drop_archive_requests(metadata) do
    metadata.request.host =~ "archive.org"
  end
end
