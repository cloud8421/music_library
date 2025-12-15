defmodule MusicLibrary.Worker.RepoOptimize do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  require Logger

  @impl Oban.Worker
  def perform(_) do
    MusicLibrary.Repo.optimize()
  end
end
