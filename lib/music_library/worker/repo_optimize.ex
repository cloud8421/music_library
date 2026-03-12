defmodule MusicLibrary.Worker.RepoOptimize do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  @impl Oban.Worker
  def perform(_) do
    MusicLibrary.Repo.optimize()
  end
end
