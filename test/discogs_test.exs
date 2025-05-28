defmodule DiscogsTest do
  use ExUnit.Case, async: true

  alias Discogs.Fixtures

  describe "get_artist/1" do
    test "it returns the artist" do
      discogs_id = "discogs_id"

      expected_info =
        Fixtures.Artist.get_artist()

      Req.Test.stub(Discogs.API, fn %{request_path: "/artists/discogs_id"} = conn ->
        Req.Test.json(conn, Fixtures.Artist.get_artist())
      end)

      assert {:ok, expected_info} == Discogs.get_artist(discogs_id)
    end
  end
end
