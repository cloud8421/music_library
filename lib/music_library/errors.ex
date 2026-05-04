defmodule MusicLibrary.Errors do
  @moduledoc """
  Queries for production errors tracked via ErrorTracker.

  Reads from the error_tracker_errors and error_tracker_occurrences tables
  (owned by the `ErrorTracker` library) through `MusicLibrary.Repo`. The
  tables are created by ErrorTracker's own migrations and do not require
  any additional schema work.
  """

  import Ecto.Query, warn: false

  alias ErrorTracker.{Error, Occurrence}
  alias MusicLibrary.Repo

  @type list_opts :: [
          status: :resolved | :unresolved,
          muted: boolean(),
          search: String.t(),
          limit: pos_integer(),
          offset: non_neg_integer()
        ]

  @type list_result :: %{
          errors: [Error.t()],
          total: non_neg_integer()
        }

  @spec list_errors(list_opts()) :: list_result()
  def list_errors(opts \\ []) do
    status = Keyword.get(opts, :status)
    muted = Keyword.get(opts, :muted)
    search = Keyword.get(opts, :search)
    limit = Keyword.get(opts, :limit, 50)
    offset = Keyword.get(opts, :offset, 0)

    base = base_query(status: status, muted: muted, search: search)

    total = Repo.aggregate(base, :count, :id)

    errors =
      base
      |> order_by(desc: :last_occurrence_at)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    %{errors: errors, total: total}
  end

  @spec get_error(pos_integer()) :: {:ok, Error.t()} | {:error, :not_found}
  def get_error(id) do
    case Repo.get(Error, id) do
      nil ->
        {:error, :not_found}

      error ->
        occurrences =
          from(o in Occurrence,
            where: o.error_id == ^id,
            order_by: [desc: o.inserted_at]
          )
          |> Repo.all()

        occurrence_count = length(occurrences)
        first_occurrence_at = get_first_occurrence_at(occurrences)

        result =
          %{error | occurrences: occurrences}
          |> Map.put(:occurrence_count, occurrence_count)
          |> Map.put(:first_occurrence_at, first_occurrence_at)

        {:ok, result}
    end
  end

  # -- private helpers --

  defp base_query(filters) do
    Error
    |> maybe_filter_status(filters[:status])
    |> maybe_filter_muted(filters[:muted])
    |> maybe_filter_search(filters[:search])
  end

  defp maybe_filter_status(query, nil), do: query
  defp maybe_filter_status(query, status), do: where(query, [e], e.status == ^status)

  defp maybe_filter_muted(query, nil), do: query
  defp maybe_filter_muted(query, muted), do: where(query, [e], e.muted == ^muted)

  defp maybe_filter_search(query, nil), do: query
  defp maybe_filter_search(query, ""), do: query

  defp maybe_filter_search(query, search) do
    where(query, [e], like(e.reason, ^"%#{search}%"))
  end

  defp get_first_occurrence_at([]), do: nil
  defp get_first_occurrence_at(occurrences), do: List.last(occurrences).inserted_at
end
