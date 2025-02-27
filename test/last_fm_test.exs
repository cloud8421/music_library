defmodule LastFmTest do
  use ExUnit.Case, async: true

  alias LastFm.{Artist, Fixtures}

  describe "get_artist_info/1" do
    test "it returns the artist info" do
      name = "Steven Wilson"
      musicbrainz_id = Ecto.UUID.generate()

      expected_info =
        Fixtures.Artist.get_info()
        |> Map.get("artist")
        |> Artist.from_api_response()

      Req.Test.stub(LastFm.API, fn conn ->
        Req.Test.json(conn, Fixtures.Artist.get_info())
      end)

      assert {:ok, expected_info} == LastFm.get_artist_info(musicbrainz_id, name)
    end
  end
end
