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

      # HTTP Metrics
      summary("finch.request.stop.duration",
        unit: {:native, :millisecond},
        tags: [:host],
        tag_values: &add_tags/1,
        drop: &drop_unwanted_hosts/1,
        reporter_options: [
          nav: "External APIs"
        ]
      ),

      # Rate Limiter
      summary("req.rate_limiter.throttle.sleep_ms",
        unit: :millisecond,
        description: "Time spent waiting for rate limit cooldown",
        tags: [:name],
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

      # Error Tracker
      counter("error_tracker.error.new.system_time",
        description: "New errors tracked",
        reporter_options: [nav: "Error Tracker"]
      ),
      counter("error_tracker.error.resolved.system_time",
        description: "Errors marked as resolved",
        reporter_options: [nav: "Error Tracker"]
      ),
      counter("error_tracker.error.unresolved.system_time",
        description: "Errors marked as unresolved",
        reporter_options: [nav: "Error Tracker"]
      ),
      counter("error_tracker.occurrence.new.system_time",
        description: "New error occurrences",
        reporter_options: [nav: "Error Tracker"]
      ),

      # Oban Job Metrics
      summary("oban.job.stop.duration",
        unit: {:native, :millisecond},
        tags: [:queue, :worker],
        tag_values: &normalize_oban_tags/1,
        reporter_options: [nav: "Oban"]
      ),
      summary("oban.job.stop.queue_time",
        unit: {:native, :millisecond},
        tags: [:queue],
        tag_values: &normalize_oban_tags/1,
        reporter_options: [nav: "Oban"]
      ),
      counter("oban.job.exception.duration",
        tags: [:queue, :worker],
        tag_values: &normalize_oban_tags/1,
        reporter_options: [nav: "Oban"]
      ),

      # Phoenix HTTP Metrics
      summary("phoenix.router_dispatch.stop.duration",
        unit: {:native, :millisecond},
        tags: [:route],
        tag_values: &phoenix_route_tag/1,
        reporter_options: [nav: "HTTP"]
      ),
      counter("phoenix.router_dispatch.stop.duration",
        tags: [:status],
        tag_values: &phoenix_status_tag/1,
        reporter_options: [nav: "HTTP"]
      ),
      counter("plug.router_dispatch.exception.duration",
        tags: [:status],
        tag_values: &router_exception_status_tag/1,
        reporter_options: [nav: "HTTP"]
      ),

      # LiveView Metrics
      summary("phoenix.live_view.mount.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view],
        tag_values: &live_view_tag/1,
        reporter_options: [nav: "LiveView"]
      ),
      summary("phoenix.live_view.handle_params.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view],
        tag_values: &live_view_tag/1,
        reporter_options: [nav: "LiveView"]
      ),
      summary("phoenix.live_view.render.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view],
        tag_values: &live_view_tag/1,
        reporter_options: [nav: "LiveView"]
      ),
      summary("phoenix.live_view.handle_event.stop.duration",
        unit: {:native, :millisecond},
        tags: [:view, :event],
        tag_values: &live_view_event_tag/1,
        reporter_options: [nav: "LiveView"]
      ),

      # Markdown Processing Metrics
      summary("markdown.to_html.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "Markdown"]
      ),

      # Color Extraction Metrics
      summary("music_library.colors.extract.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "Image Processing"]
      ),

      # Image Processing Metrics
      summary("music_library.assets.image.resize.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "Image Processing"]
      ),
      summary("music_library.assets.image.convert.stop.duration",
        unit: {:native, :millisecond},
        reporter_options: [nav: "Image Processing"]
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

  defp drop_unwanted_hosts(metadata) do
    metadata.request.host =~ "archive.org"
  end

  defp normalize_oban_tags(%{job: job}) do
    worker = job.worker |> String.split(".") |> List.last()
    %{queue: job.queue, worker: worker}
  end

  defp phoenix_route_tag(%{route: route}), do: %{route: route}
  defp phoenix_route_tag(_metadata), do: %{route: "unknown"}

  defp phoenix_status_tag(%{conn: %{status: status}}), do: %{status: to_string(status)}
  defp phoenix_status_tag(_metadata), do: %{status: "unknown"}

  defp router_exception_status_tag(%{kind: :error, reason: reason}) do
    %{status: reason |> Plug.Exception.status() |> to_string()}
  end

  defp router_exception_status_tag(_metadata), do: %{status: "500"}

  defp live_view_tag(%{socket: %{view: view}}) do
    module = view |> inspect() |> String.split(".") |> Enum.take(-2) |> Enum.join(".")
    %{view: module}
  end

  defp live_view_tag(_metadata), do: %{view: "unknown"}

  defp live_view_event_tag(%{socket: %{view: view}, event: event}) do
    module = view |> inspect() |> String.split(".") |> Enum.take(-2) |> Enum.join(".")
    %{view: module, event: event}
  end

  defp live_view_event_tag(%{event: event}), do: %{view: "unknown", event: event}
  defp live_view_event_tag(_metadata), do: %{view: "unknown", event: "unknown"}
end
