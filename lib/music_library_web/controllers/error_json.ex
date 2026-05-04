defmodule MusicLibraryWeb.ErrorJSON do
  @moduledoc """
  JSON rendering for production errors via the API and for Phoenix error responses.

  This module serves dual purpose:
  - Renders error/occurrence data for the /api/v1/errors endpoints
  - Renders generic error responses (404, 500, etc.) for the Phoenix endpoint
    when the request accepts JSON (configured in config/config.exs render_errors)
  """
  use MusicLibraryWeb, :json

  # Catch-all for Phoenix error template rendering (404, 500, etc.)
  def render(template, _assigns) do
    %{error: Phoenix.Controller.status_message_from_template(template)}
  end

  def index(%{errors: errors, total: total, limit: limit, offset: offset}) do
    %{
      errors: Enum.map(errors, &error/1),
      total: total,
      limit: limit,
      offset: offset
    }
  end

  def show(%{error: error}) do
    %{
      error: error_with_occurrences(error)
    }
  end

  defp error(e) do
    %{
      id: e.id,
      kind: e.kind,
      reason: e.reason,
      source_line: e.source_line,
      source_function: e.source_function,
      status: atom_to_string(e.status),
      fingerprint: e.fingerprint,
      last_occurrence_at: datetime_to_iso8601(e.last_occurrence_at),
      muted: e.muted,
      inserted_at: datetime_to_iso8601(e.inserted_at),
      updated_at: datetime_to_iso8601(e.updated_at)
    }
  end

  defp error_with_occurrences(e) do
    error(e)
    |> Map.put(:occurrence_count, Map.get(e, :occurrence_count, 0))
    |> Map.put(:first_occurrence_at, datetime_to_iso8601(Map.get(e, :first_occurrence_at)))
    |> Map.put(:occurrences, Enum.map(Map.get(e, :occurrences, []), &occurrence/1))
  end

  defp occurrence(o) do
    %{
      id: o.id,
      reason: o.reason,
      context: o.context,
      breadcrumbs: o.breadcrumbs,
      stacktrace: %{
        lines: Enum.map(o.stacktrace.lines, &stacktrace_line/1)
      },
      error_id: o.error_id,
      inserted_at: datetime_to_iso8601(o.inserted_at)
    }
  end

  defp stacktrace_line(line) do
    %{
      application: line.application,
      module: line.module,
      function: line.function,
      arity: line.arity,
      file: line.file,
      line: line.line
    }
  end

  defp datetime_to_iso8601(nil), do: nil
  defp datetime_to_iso8601(dt), do: DateTime.to_iso8601(dt)

  defp atom_to_string(nil), do: nil
  defp atom_to_string(atom), do: Atom.to_string(atom)
end
