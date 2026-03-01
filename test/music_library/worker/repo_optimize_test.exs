defmodule MusicLibrary.Worker.RepoOptimizeTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Worker.RepoOptimize

  describe "perform/1" do
    test "runs optimize on the repo" do
      assert {:ok, %Exqlite.Result{}} = perform_job(RepoOptimize, %{})
    end
  end
end
