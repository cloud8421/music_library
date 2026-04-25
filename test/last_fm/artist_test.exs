defmodule LastFm.ArtistTest do
  use ExUnit.Case, async: true

  @api_response_path Path.expand("../support/fixtures/last_fm/artist.getinfo.json", __DIR__)

  describe "from_api_response/1" do
    test "returns correct data" do
      api_response =
        @api_response_path
        |> File.read!()
        |> JSON.decode!()
        |> Map.get("artist")

      assert %LastFm.Artist{
               musicbrainz_id: "3a51b862-0144-40f6-aa17-6aaeefea29d9",
               name: "Steven Wilson",
               summary:
                 "Steven Wilson (born Steven John Wilson on November 3, 1967, in Hemel Hempstead, Hertfordshire, England) is an English musician, singer, songwriter and record producer, most closely associated with the progressive rock genre. Currently a solo artist, he became known as the founder, lead guitarist, lead vocalist and songwriter of the British rock band Porcupine Tree, as well as being a member of several other bands.\n\nWilson is self-taught as a producer, audio engineer, multi-instrumentalist and singer-songwriter. <a href=\"https://www.last.fm/music/Steven+Wilson\">Read more on Last.fm</a>",
               bio:
                 "Steven Wilson (born Steven John Wilson on November 3, 1967, in Hemel Hempstead, Hertfordshire, England) is an English musician, singer, songwriter and record producer, most closely associated with the progressive rock genre. Currently a solo artist, he became known as the founder, lead guitarist, lead vocalist and songwriter of the British rock band Porcupine Tree, as well as being a member of several other bands.\n\nWilson is self-taught as a producer, audio engineer, multi-instrumentalist and singer-songwriter. Under his own name, he has released the albums Insurgentes  (2008), Grace for Drowning  (2011), The Raven That Refused to Sing (and Other Stories)  (2013), Hand. Cannot. Erase.  (2015), To the Bone (2017), and The Future Bites  (2021). He also released a EP, 4 ½  (2016), as well as a series of singles titled Cover Version (released online between 2003 and 2010; released worldwide as a compilation in 2014). His other solo projects can also be found attributed to monikers of his, such as Bass Communion and Incredible Expanding Mindfuck.\n\nHe is perhaps best known as the frontman for progressive rock band, Porcupine Tree, for whom he was the sole member during the 1980s and early 1990s. His projects are numerous however, including collaboration with Aviv Geffen as Blackfield; a long-running partnership with Tim Bowness, known as No-Man; teaming up with Dirk Serries in Continuum; as well as a joint album with Opeth's frontman, Mikael Åkerfeldt in Storm Corrosion.\n\n\nWilson employs synthesizers and programmed music along with live instruments to create a unique atmosphere for each song he works on, including otherwise-simple pop tunes. In addition to his prolific musical output, Steven has crafted a reputation for the high production quality of his music, and has undertaken production duties with such high-profile artists as Opeth, Dream Theater, Jim Matheos of Fates Warning, Anathema, Orphaned Land,  Marillion, Fish, Pendulum, Yoko Ono, and friend Robert Fripp. He is also part way through remixing the albums of King Crimson and other classic artists' back catalogues into surround sound and new stereo mixes. <a href=\"https://www.last.fm/music/Steven+Wilson\">Read more on Last.fm</a>. User-contributed text is available under the Creative Commons By-SA License; additional terms may apply.",
               image:
                 "https://lastfm.freetls.fastly.net/i/u/300x300/2a96cbd8b46e442fc41c2b86b821562f.png",
               play_count: 123,
               base_url: "https://www.last.fm/music/Steven+Wilson"
             } ==
               LastFm.Artist.from_api_response(api_response)
    end
  end
end
