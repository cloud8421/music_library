defmodule MusicLibrary.Maintenance do
  @moduledoc """
  Context for database maintenance operations and background job monitoring.
  """

  import Ecto.Query

  alias MusicLibrary.BackgroundRepo
  alias MusicLibrary.Repo

  @doc """
  Counts active Oban jobs for the given worker module name.

  Active jobs are those in "available", "scheduled", "executing", or "retryable" states.
  """
  def count_active_jobs(worker) do
    query =
      from j in Oban.Job,
        where: j.worker == ^worker,
        where: j.state in ["available", "scheduled", "executing", "retryable"],
        select: count(j.id)

    BackgroundRepo.one(query)
  end

  @doc """
  Runs VACUUM on the main database.
  """
  def vacuum do
    Repo.vacuum()
  end

  @doc """
  Runs PRAGMA optimize on the main database.
  """
  def optimize do
    Repo.optimize()
  end
end
