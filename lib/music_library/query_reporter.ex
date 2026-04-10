defmodule MusicLibrary.QueryReporter do
  @moduledoc """
  Dev-only Ecto query reporter that captures executed SQL queries to a file.

  Attaches to the main Repo's telemetry event and writes each query as
  executable SQL with interpolated parameters and source location comments.
  Designed to be activated at runtime via Tidewave's `project_eval`.

  ## Usage

      MusicLibrary.QueryReporter.start("/tmp/queries.sql")
      # ... trigger actions ...
      MusicLibrary.QueryReporter.stop()
      # read /tmp/queries.sql for captured queries
  """

  alias Ecto.Adapters.SQL

  require Logger

  @handler_id "music-library-query-reporter"
  @event [:music_library, :repo, :query]

  @doc """
  Starts capturing queries to the given file path.

  Truncates the file if it exists. Calling `start/1` while already running
  restarts with a new file.
  """
  # sobelow_skip ["Traversal.FileModule"]
  @spec start(String.t()) :: :ok
  def start(file_path) when is_binary(file_path) do
    # Path is provided by the developer at runtime via IEx/Tidewave
    File.write!(file_path, "-- Query Reporter started at #{DateTime.utc_now()}\n\n")

    :telemetry.detach(@handler_id)

    :ok =
      :telemetry.attach(
        @handler_id,
        @event,
        &__MODULE__.handle_event/4,
        file_path
      )
  end

  @doc """
  Stops capturing queries.
  """
  @spec stop() :: :ok | {:error, String.t()}
  def stop do
    case :telemetry.detach(@handler_id) do
      :ok -> :ok
      {:error, :not_found} -> {:error, "Query reporter is not running"}
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  @doc false
  def handle_event(@event, measurements, metadata, file_path) do
    entry = format_entry(metadata, measurements)
    # Path is provided by the developer at runtime via IEx/Tidewave
    File.write!(file_path, entry, [:append])
  rescue
    error ->
      Logger.warning("QueryReporter failed to write: #{inspect(error)}")
  end

  defp format_entry(metadata, measurements) do
    params = metadata.cast_params || metadata.params || []
    query = interpolate_query(metadata.query, params)
    location = extract_source_location(metadata.stacktrace)
    timing = format_timing(measurements)

    IO.iodata_to_binary([
      if(location, do: [location, "\n"], else: []),
      timing,
      "\n",
      String.trim_trailing(query),
      ";\n\n"
    ])
  end

  defp format_timing(measurements) do
    parts =
      [:total_time, :query_time, :queue_time, :decode_time]
      |> Enum.flat_map(fn key ->
        case Map.get(measurements, key) do
          nil -> []
          value -> [{key, to_ms(value)}]
        end
      end)

    label = fn
      :total_time -> "total"
      :query_time -> "db"
      :queue_time -> "queue"
      :decode_time -> "decode"
    end

    formatted = Enum.map_join(parts, " ", fn {key, ms} -> "#{label.(key)}=#{ms}ms" end)
    "-- #{formatted}"
  end

  defp to_ms(native) do
    us = System.convert_time_unit(native, :native, :microsecond)
    Float.round(us / 1000, 1)
  end

  defp interpolate_query(query, []), do: query

  defp interpolate_query(query, params) do
    parts = String.split(query, "?")

    parts
    |> Enum.zip_reduce(params ++ [:done], [], fn
      part, :done, acc -> [part | acc]
      part, param, acc -> [format_param(param), part | acc]
    end)
    |> Enum.reverse()
    |> IO.iodata_to_binary()
  end

  defp format_param(nil), do: "NULL"
  defp format_param(value) when is_integer(value), do: Integer.to_string(value)
  defp format_param(value) when is_float(value), do: Float.to_string(value)
  defp format_param(true), do: "1"
  defp format_param(false), do: "0"

  defp format_param(value) when is_binary(value) do
    if String.printable?(value) do
      "'" <> String.replace(value, "'", "''") <> "'"
    else
      "X'" <> Base.encode16(value) <> "'"
    end
  end

  defp format_param(value), do: "'" <> String.replace(to_string(value), "'", "''") <> "'"

  defp extract_source_location(nil), do: nil
  defp extract_source_location([]), do: nil

  defp extract_source_location(stacktrace) do
    case SQL.first_non_ecto_stacktrace(stacktrace, %{repo: MusicLibrary.Repo}, 1) do
      [{module, function, arity, info}] ->
        format_location(module, function, arity, info)

      _ ->
        nil
    end
  end

  defp format_location(module, function, arity, info) do
    mfa = Exception.format_mfa(module, function, arity)

    case Keyword.fetch(info, :file) do
      {:ok, file} ->
        line = Keyword.get(info, :line, "?")
        "-- #{mfa}, at: #{file}:#{line}"

      :error ->
        "-- #{mfa}"
    end
  end
end
