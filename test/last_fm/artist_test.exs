defmodule LastFm.ArtistTest do
  use ExUnit.Case, async: true

  @api_response_path Path.expand("../support/fixtures/artist.getinfo.json", __DIR__)

  describe "from_api_response/1" do
    test "returns correct data" do
      api_response =
        @api_response_path
        |> File.read!()
        |> Jason.decode!()
        |> Map.get("artist")

      assert %LastFm.Artist{
               musicbrainz_id: "3a51b862-0144-40f6-aa17-6aaeefea29d9",
               name: "Steven Wilson",
               bio:
                 "Steven Wilson (born Steven John Wilson on November 3, 1967, in Hemel Hempstead, Hertfordshire, England) is an English musician, singer, songwriter and record producer, most closely associated with the progressive rock genre. Currently a solo artist, he became known as the founder, lead guitarist, lead vocalist and songwriter of the British rock band Porcupine Tree, as well as being a member of several other bands.\n\nWilson is self-taught as a producer, audio engineer, multi-instrumentalist and singer-songwriter. <a href=\"https://www.last.fm/music/Steven+Wilson\">Read more on Last.fm</a>",
               image:
                 "https://lastfm.freetls.fastly.net/i/u/64s/2a96cbd8b46e442fc41c2b86b821562f.png",
               play_count: 123
             } ==
               LastFm.Artist.from_api_response(api_response)
    end
  end
end
