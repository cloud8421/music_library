defmodule LastFmTest do
  use ExUnit.Case, async: true

  alias LastFm.APIMock
  alias LastFm.Fixtures.Artist
  import Mox

  setup :verify_on_exit!

  describe "get_artist_info/1" do
    test "it returns the artist info" do
      name = "Steven Wilson"
      musicbrainz_id = Ecto.UUID.generate()
      expected_info = Artist.get_info()

      expect(APIMock, :get_artist_info, fn {:musicbrainz_id, ^musicbrainz_id}, _config ->
        {:ok, expected_info}
      end)

      assert {:ok, expected_info} == LastFm.get_artist_info(musicbrainz_id, name)
    end
  end
end
