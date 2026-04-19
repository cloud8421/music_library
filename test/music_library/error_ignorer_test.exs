defmodule MusicLibrary.ErrorIgnorerTest do
  use ExUnit.Case, async: true

  alias MusicLibrary.ErrorIgnorer

  describe "ignore?/2" do
    test "ignores Phoenix.Router.NoRouteError" do
      error = %ErrorTracker.Error{kind: "Elixir.Phoenix.Router.NoRouteError"}
      assert ErrorIgnorer.ignore?(error, %{}) == true
    end

    test "does not ignore other error kinds" do
      error = %ErrorTracker.Error{kind: "Elixir.RuntimeError"}
      assert ErrorIgnorer.ignore?(error, %{}) == false
    end

    test "does not ignore Ecto.NoResultsError" do
      error = %ErrorTracker.Error{kind: "Elixir.Ecto.NoResultsError"}
      assert ErrorIgnorer.ignore?(error, %{}) == false
    end
  end
end
