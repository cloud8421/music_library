defmodule MusicLibrary.RepoTest do
  alias MusicLibrary.ReleaseGroupsFixtures
  use MusicLibrary.DataCase

  describe "correctly loads the unicode extension" do
    test "unaccent function" do
      {:ok, result} = MusicLibrary.Repo.query("SELECT unaccent('héllö')")
      assert [["hello"]] == result.rows
    end
  end
end
