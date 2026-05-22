defmodule MusicLibrary.Assets.Cache do
  @moduledoc """
  ETS-based asset cache with TTL for serving frequently accessed images.

  ## Cache key

  Each entry is keyed by `{key, format}` where `key` is an opaque canonical
  transform key provided by the caller (currently `"hash:width"` from
  `Transform.canonical_key/1`) and `format` is the output MIME type
  (e.g. `"image/webp"`).

  ## TTL and pruning

  The TTL is configured via the `@one_week_seconds` module attribute
  (`60 * 60 * 24 * 7` = 7 days). The `prune/0` function deletes all entries
  whose `inserted_at` timestamp is older than this threshold.

  Pruning runs automatically every 12 hours via the `PruneAssetCache` Oban
  cron worker.

  ## Invalidation strategy

  This cache uses **TTL-based expiry only** — there is no explicit
  invalidation. This is sufficient because:

  1. Assets are content-addressable (SHA256 hashes) and immutable once
     written. When an image is replaced (e.g. a new cover is uploaded),
     the new asset gets a new hash, producing a different cache key. The
     old entry is never requested again and naturally expires.

  2. The ETS table is in-memory and cleared on application restart.

  Explicit invalidation would add complexity (tracking which cache entries
  derive from which original asset hash) with no practical benefit given
  the above properties.
  """

  @spec new() :: :ets.table()
  def new do
    :ets.new(__MODULE__, [:named_table, :public, :compressed, read_concurrency: true])
  end

  @spec set(String.t(), String.t(), binary()) :: true
  def set(payload, format, content) do
    inserted_at = DateTime.utc_now() |> DateTime.to_unix()
    :ets.insert(__MODULE__, {{payload, format}, inserted_at, content})
  end

  @spec get(String.t(), String.t()) :: {:found, binary()} | :not_found
  def get(payload, format) do
    case :ets.lookup(__MODULE__, {payload, format}) do
      [{{^payload, ^format}, _inserted_at, content}] -> {:found, content}
      [] -> :not_found
    end
  end

  @spec total_content_size() :: non_neg_integer()
  def total_content_size do
    :ets.foldl(
      fn {_key, _inserted_at, content}, acc -> acc + byte_size(content) end,
      0,
      __MODULE__
    )
  end

  @one_week_seconds 60 * 60 * 24 * 7

  @spec prune(non_neg_integer()) :: non_neg_integer()
  def prune(older_than_seconds \\ @one_week_seconds) do
    threshold =
      DateTime.utc_now()
      |> DateTime.add(older_than_seconds * -1, :second)
      |> DateTime.to_unix()

    :ets.select_delete(
      __MODULE__,
      [{{:"$1", :"$2", :"$3"}, [{:<, :"$2", threshold}], [true]}]
    )
  end
end
