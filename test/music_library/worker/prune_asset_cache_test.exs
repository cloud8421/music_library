defmodule MusicLibrary.Worker.PruneAssetCacheTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Assets.Cache
  alias MusicLibrary.Worker.PruneAssetCache

  describe "perform/1" do
    @describetag :capture_log

    test "prunes old cache entries" do
      # Insert a cache entry with an old timestamp
      old_timestamp = DateTime.utc_now() |> DateTime.add(-8, :day) |> DateTime.to_unix()
      :ets.insert(Cache, {{"old_payload", "image/jpeg"}, old_timestamp, "old_content"})

      # Insert a recent cache entry
      Cache.set("recent_payload", "image/jpeg", "recent_content")

      assert :ok = perform_job(PruneAssetCache, %{})

      assert Cache.get("old_payload", "image/jpeg") == :not_found
      assert {:found, "recent_content"} = Cache.get("recent_payload", "image/jpeg")
    end

    test "succeeds with empty cache" do
      assert :ok = perform_job(PruneAssetCache, %{})
    end
  end
end
