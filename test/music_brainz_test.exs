defmodule MusicBrainzTest do
  use ExUnit.Case, async: true

  alias MusicBrainz.APIBehaviourMock
  import MusicLibrary.Fixtures.ReleaseGroup
  import Mox

  setup :verify_on_exit!

  describe "search_release_group/2" do
    test "it returns results with correct limit and offset" do
      mock_results = release_group_search_results()

      expect(APIBehaviourMock, :search_release_group, fn "Marillion",
                                                         [limit: 20, offset: 10],
                                                         _config ->
        {:ok, mock_results}
      end)

      assert {:ok, mock_results} ==
               MusicBrainz.search_release_group("Marillion", limit: 20, offset: 10)
    end
  end
end
