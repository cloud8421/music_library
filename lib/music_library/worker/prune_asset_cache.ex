defmodule MusicLibrary.Worker.PruneAssetCache do
  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger

  alias MusicLibrary.Assets.Cache

  @impl Oban.Worker
  def perform(_) do
    prune_count = Cache.prune()

    Logger.info(fn ->
      "Pruned #{prune_count} old cached assets. Cache size now #{Cache.total_content_size()} bytes."
    end)
  end
end
