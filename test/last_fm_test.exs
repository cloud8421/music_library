defmodule LastFmTest do
  use ExUnit.Case, async: true

  alias LastFm.{Artist, Fixtures, Scrobble}

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

  describe "scrobble/2" do
    test "it returns the scrobbled track" do
      scrobbles = [
        %Scrobble{
          track: "Wonderland",
          artist: "IQ",
          album: "Dominion",
          timestamp: 1_746_561_301,
          mbid: "aefaaf73-b52c-4b0d-91df-f8e4321db2bd"
        }
      ]

      session_key = "session_key"

      response_body = %{
        "scrobbles" => %{
          "@attr" => %{"accepted" => 1, "ignored" => 0},
          "scrobble" => %{
            "album" => %{"#text" => "Dominion", "corrected" => "0"},
            "albumArtist" => %{"#text" => "", "corrected" => "0"},
            "artist" => %{"#text" => "IQ", "corrected" => "0"},
            "ignoredMessage" => %{"#text" => "", "code" => "1"},
            "timestamp" => "1746561301",
            "track" => %{"#text" => "Wonderland", "corrected" => "0"}
          }
        }
      }

      Req.Test.stub(LastFm.API, fn conn ->
        assert conn.body_params == %{
                 "album" => %{"0" => "Dominion"},
                 "api_key" => "change me",
                 "api_sig" => "f3c0644ba671654aafb2396806c4b96f",
                 "artist" => %{"0" => "IQ"},
                 "format" => "json",
                 "mbid" => %{"0" => "aefaaf73-b52c-4b0d-91df-f8e4321db2bd"},
                 "method" => "track.scrobble",
                 "sk" => "session_key",
                 "timestamp" => %{"0" => "1746561301"},
                 "track" => %{"0" => "Wonderland"}
               }

        Req.Test.json(conn, response_body)
      end)

      assert {:ok, response_body} == LastFm.scrobble(scrobbles, session_key)
    end
  end
end
