defmodule MusicLibrary.Worker.PruneAssets do
  @moduledoc """
  Prunes unreferenced assets from the database.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias MusicLibrary.Assets

  @impl Oban.Worker
  def perform(_) do
    count = Assets.prune_unreferenced()

    Logger.info(fn -> "Pruned #{count} unreferenced assets." end)
  end
end
