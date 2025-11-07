defmodule MusicLibrary.Worker.PruneAssets do
  use Oban.Worker, queue: :default, max_attempts: 3

  import Ecto.Query

  require Logger

  alias MusicLibrary.{
    Artists.ArtistInfo,
    Assets.Asset,
    Records.Record,
    Repo
  }

  @impl Oban.Worker
  def perform(_) do
    # Find all assets that are not referenced by any records or artist info
    # Note that SQLite doesn't support left joins on delete, so we do it in two steps.
    asset_hashes =
      from a in Asset,
        left_join: r in Record,
        on: r.cover_hash == a.hash,
        left_join: ai in ArtistInfo,
        on: ai.image_data_hash == a.hash,
        where: is_nil(r.id) and is_nil(ai.id),
        select: a.hash

    q =
      from a in Asset,
        where: a.hash in subquery(asset_hashes)

    {count, nil} = Repo.delete_all(q)

    Logger.info("Pruned #{count} unreferenced assets.")
  end
end
