defmodule MusicLibrary.Errors do
  @moduledoc """
  Queries and mutations for production errors tracked via ErrorTracker.

  Reads from the error_tracker_errors and error_tracker_occurrences tables
  (owned by the `ErrorTracker` library) through `MusicLibrary.Repo`. The
  tables are created by ErrorTracker's own migrations and do not require
  any additional schema work.

  Provides `mute_error/1`, `unmute_error/1`, `resolve_error/1`, and
  `unresolve_error/1` for mutating error state (muted flag and status).
  Muting an error suppresses future email notifications via
  `ErrorTracker.ErrorNotifier`, which checks the `muted` field before
  dispatching.
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

  @type error_detail :: %{
          required(:id) => pos_integer(),
          required(:kind) => String.t() | nil,
          required(:reason) => String.t() | nil,
          required(:source_line) => String.t() | nil,
          required(:source_function) => String.t() | nil,
          required(:status) => :resolved | :unresolved | nil,
          required(:fingerprint) => binary() | nil,
          required(:last_occurrence_at) => DateTime.t() | nil,
          required(:muted) => boolean() | nil,
          required(:inserted_at) => DateTime.t() | nil,
          required(:updated_at) => DateTime.t() | nil,
          required(:occurrences) => [Occurrence.t()],
          required(:occurrence_count) => non_neg_integer(),
          required(:first_occurrence_at) => DateTime.t() | nil,
          optional(atom()) => term()
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

  @spec get_error(pos_integer()) :: {:ok, error_detail()} | {:error, :not_found}
  def get_error(id) do
    case get_error_record(id) do
      nil ->
        {:error, :not_found}

      error ->
        occurrences =
          from(o in Occurrence,
            where: o.error_id == ^id,
            order_by: [desc: o.inserted_at]
          )
          |> Repo.all()

        occurrence_count =
          from(o in Occurrence, where: o.error_id == ^id)
          |> Repo.aggregate(:count, :id)

        first_occurrence_at =
          from(o in Occurrence, where: o.error_id == ^id)
          |> Repo.aggregate(:min, :inserted_at)

        result =
          error
          |> Map.put(:occurrences, occurrences)
          |> Map.put(:occurrence_count, occurrence_count)
          |> Map.put(:first_occurrence_at, first_occurrence_at)

        {:ok, result}
    end
  end

  @spec mute_error(pos_integer()) :: {:ok, Error.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def mute_error(id) do
    case get_error_record(id) do
      nil -> {:error, :not_found}
      %{muted: true} = error -> {:ok, error}
      error -> ErrorTracker.mute(error)
    end
  end

  @spec unmute_error(pos_integer()) ::
          {:ok, Error.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def unmute_error(id) do
    case get_error_record(id) do
      nil -> {:error, :not_found}
      %{muted: false} = error -> {:ok, error}
      error -> ErrorTracker.unmute(error)
    end
  end

  @spec resolve_error(pos_integer()) ::
          {:ok, Error.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def resolve_error(id) do
    case get_error_record(id) do
      nil -> {:error, :not_found}
      %{status: :resolved} = error -> {:ok, error}
      error -> ErrorTracker.resolve(error)
    end
  end

  @spec unresolve_error(pos_integer()) ::
          {:ok, Error.t()} | {:error, :not_found | Ecto.Changeset.t()}
  def unresolve_error(id) do
    case get_error_record(id) do
      nil -> {:error, :not_found}
      %{status: :unresolved} = error -> {:ok, error}
      error -> ErrorTracker.unresolve(error)
    end
  end

  @spec get_error_record(pos_integer()) :: Error.t() | nil
  defp get_error_record(id) do
    from(e in Error, where: e.id == ^id)
    |> Repo.one()
  end

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
    escaped = escape_like_wildcards(search)
    where(query, [e], fragment("? LIKE ? ESCAPE '\\'", e.reason, ^"%#{escaped}%"))
  end

  @doc false
  def escape_like_wildcards(search) when is_binary(search) do
    search
    |> String.replace("\\", "\\\\")
    |> String.replace("%", "\\%")
    |> String.replace("_", "\\_")
  end
end
