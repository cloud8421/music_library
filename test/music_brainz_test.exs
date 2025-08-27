defmodule MusicBrainzTest do
  use ExUnit.Case, async: true

  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup

  alias MusicBrainz.ReleaseGroupSearchResult

  describe "search_release_group/2" do
    test "it returns results with correct limit and offset" do
      results = release_group_search_results()

      expected_results =
        Enum.map(results["release-groups"], &ReleaseGroupSearchResult.from_api_response/1)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, results)
      end)

      assert {:ok, result} =
               MusicBrainz.search_release_group("Marillion", limit: 20, offset: 10)

      assert result.release_groups == expected_results
      assert result.total_count == 437
    end
  end

  describe "search_release_by_barcode/1" do
    test "it returns releases belonging to the same release group" do
      barcode = "5052205070023"

      releases =
        releases(:queen_greatest_hits)

      Req.Test.stub(MusicBrainz.API, fn conn ->
        Req.Test.json(conn, releases)
      end)

      assert {:ok, results} =
               MusicBrainz.search_release_by_barcode(barcode)

      assert Enum.all?(results, fn result ->
               result.release_group.id == "69ce61c8-127f-3809-95d8-62fdf3ae1347" &&
                 result.release_group.title == "Greatest Hits"
             end)
    end
  end
end
