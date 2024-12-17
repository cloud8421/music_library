defmodule MusicLibrary.RepoTest do
  use MusicLibrary.DataCase

  describe "correctly loads the unicode extension" do
    test "unaccent function" do
      {:ok, result} = MusicLibrary.Repo.query("SELECT unaccent('héllö')")
      assert [["hello"]] == result.rows
    end
  end

  describe "correctly loads the vec0 (sqlite-vec) extension" do
    test "returns the version" do
      {:ok, result} = MusicLibrary.Repo.query("SELECT vec_version()")
      assert [["v0.1.6"]] == result.rows
    end
  end
end
