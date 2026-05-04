defmodule MusicLibrary.Logger.SingleLineFormatter do
  @moduledoc """
  Production-only safety net for single-line log output.

  Replaces any embedded newline characters (`\\n`) in log messages with
  escaped `\\\\n` so every physical log line corresponds to exactly one
  log event.  This makes log files reliably filterable with line-oriented
  tools (grep, tail, sort) and enables deterministic reverse-order
  reading.

  ## Design

  The formatter is configured **only in `config/prod.exs`** via:

      config :logger, :default_formatter,
        format: {MusicLibrary.Logger.SingleLineFormatter, :format},
        metadata: [:request_id, :pid]

  Developers continue to see multi-line logs for readability.
  Logster v2 handles HTTP-request and LiveView-socket telemetry;
  this module acts as the universal safety net for anything Logster
  does not cover (e.g. stack traces emitted by the Erlang runtime).
  """

  # Elixir Logger.Formatter calls `apply(mod, fun, [level, msg, ts, md])`
  # where `msg` is the chardata from `format_event/2`.
  #
  # We return a flat binary (valid IO.chardata) so callers can always
  # convert it with `IO.chardata_to_string/1`.

  @doc """
  Formats a log event as a single line.

  Returns a binary ending with exactly one newline character.
  """
  @spec format(atom(), IO.chardata(), Logger.Formatter.date_time_ms(), keyword()) :: IO.chardata()
  def format(level, message, timestamp, metadata) do
    cleaned = message |> flatten_message() |> escape_newlines()
    "#{format_time(timestamp)} #{format_metadata(metadata)}[#{level}] #{cleaned}\n"
  end

  # -- helpers ---------------------------------------------------------------

  defp flatten_message(message) when is_binary(message), do: message

  defp flatten_message(message) when is_list(message) do
    IO.chardata_to_string(message)
  rescue
    UnicodeConversionError -> inspect(message)
  end

  defp flatten_message(other), do: inspect(other)

  defp escape_newlines(string), do: String.replace(string, "\n", "\\n")

  # Match the standard Logger.Formatter.format_time/1 output: "HH:MM:SS.sss"
  defp format_time({_date, {hh, mi, ss, ms}}) do
    [pad2(hh), ?:, pad2(mi), ?:, pad2(ss), ?., pad3(ms)]
    |> IO.iodata_to_binary()
  end

  defp pad2(int) when int < 10, do: [?0, Integer.to_string(int)]
  defp pad2(int), do: Integer.to_string(int)

  defp pad3(int) when int < 10, do: [?0, ?0, Integer.to_string(int)]
  defp pad3(int) when int < 100, do: [?0, Integer.to_string(int)]
  defp pad3(int), do: Integer.to_string(int)

  # Format metadata as "key=value " pairs, matching the standard Logger formatter.
  defp format_metadata([]), do: ""

  defp format_metadata(metadata) do
    case metadata |> build_meta_pairs() |> Enum.reject(&is_nil/1) do
      [] -> ""
      pairs -> Enum.join(pairs) <> " "
    end
  end

  defp build_meta_pairs(metadata) do
    Enum.map(metadata, fn {key, value} -> format_meta_pair(key, value) end)
  end

  defp format_meta_pair(:request_id, value), do: meta_string("request_id", value)
  defp format_meta_pair(:pid, value), do: meta_string("pid", value)
  defp format_meta_pair(:module, value), do: meta_string("module", value)
  defp format_meta_pair(:function, value), do: meta_string("function", value)
  defp format_meta_pair(:line, value), do: meta_string("line", value)
  defp format_meta_pair(:domain, value), do: meta_domain(value)
  defp format_meta_pair(key, value), do: "#{key}=#{inspect(value)} "

  defp meta_string(_key, nil), do: nil

  defp meta_string(key, value) when is_binary(value) do
    "#{key}=#{value} "
  end

  defp meta_string(key, value) when is_integer(value) do
    "#{key}=#{value} "
  end

  defp meta_string(key, value) when is_atom(value) do
    "#{key}=#{value} "
  end

  defp meta_string(key, value) when is_pid(value) do
    "#{key}=#{inspect(value)} "
  end

  defp meta_string(key, value) do
    "#{key}=#{value} "
  end

  defp meta_domain(nil), do: nil

  defp meta_domain([head | tail]) when is_atom(head) do
    domain = Enum.map_intersperse([head | tail], ".", &Atom.to_string/1)
    "domain=#{domain} "
  end

  defp meta_domain(other) do
    "domain=#{other} "
  end
end
