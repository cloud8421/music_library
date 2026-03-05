defmodule MusicLibrary.MaintenanceTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Maintenance

  describe "vacuum/0" do
    test "delegates to Repo.vacuum/0" do
      # VACUUM cannot run inside the Ecto sandbox transaction,
      # so we verify it attempts the operation and returns the expected tuple shape.
      assert {:error, %Exqlite.Error{message: "cannot VACUUM from within a transaction"}} =
               Maintenance.vacuum()
    end
  end

  describe "optimize/0" do
    test "returns {:ok, _}" do
      assert {:ok, _} = Maintenance.optimize()
    end
  end

  describe "count_active_jobs/1" do
    test "returns 0 for a worker with no jobs" do
      assert Maintenance.count_active_jobs("MusicLibrary.Worker.NonExistent") == 0
    end
  end
end
