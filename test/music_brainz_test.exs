defmodule MusicBrainzTest do
  use ExUnit.Case, async: true

  alias MusicBrainz.{APIMock, ReleaseSearchResult}
  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup
  import Mox

  setup :verify_on_exit!

  describe "search_release_group/2" do
    test "it returns results with correct limit and offset" do
      mock_results = release_group_search_results()

      expect(APIMock, :search_release_group, fn "Marillion", [limit: 20, offset: 10], _config ->
        {:ok, mock_results}
      end)

      assert {:ok, mock_results} ==
               MusicBrainz.search_release_group("Marillion", limit: 20, offset: 10)
    end
  end

  describe "search_release_by_barcode/1" do
    test "it returns releases belonging to the same release group" do
      barcode = "5052205070023"
      releases = releases(:queen_greatest_hits)

      expect(APIMock, :search_release_by_barcode, fn ^barcode, _config ->
        {:ok, Enum.map(releases, &ReleaseSearchResult.from_api_response/1)}
      end)

      assert {:ok, results} = MusicBrainz.search_release_by_barcode(barcode)

      assert Enum.all?(results, fn result ->
               result.release_group.id == "69ce61c8-127f-3809-95d8-62fdf3ae1347" &&
                 result.release_group.title == "Greatest Hits"
             end)
    end
  end
end
