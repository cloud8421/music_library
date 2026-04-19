defmodule LastFm.TrackTest do
  use ExUnit.Case, async: true

  alias LastFm.Fixtures.RecentTracks

  describe "from_api_response/1" do
    test "returns correct data" do
      api_response = get_in(RecentTracks.get(), ["recenttracks", "track"])

      assert [
               %LastFm.Track{
                 musicbrainz_id: "190567f8-900e-44ce-a574-69adc10cf93a",
                 title: "Gameboy Tune",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "35ac1700-84f1-4bd9-924b-3792b742e618",
                   name: "Tomáš Dvořák"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "4bad26f6-1b27-4554-93bd-40b91ed7866c",
                   title: "Machinarium Soundtrack"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_678_348,
                 scrobbled_at_label: "03 Nov 2024, 23:59",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "Machinarium Soundtrack",
                     "mbid" => "4bad26f6-1b27-4554-93bd-40b91ed7866c"
                   },
                   "artist" => %{
                     "#text" => "Tomáš Dvořák",
                     "mbid" => "35ac1700-84f1-4bd9-924b-3792b742e618"
                   },
                   "date" => %{"#text" => "03 Nov 2024, 23:59", "uts" => "1730678348"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "190567f8-900e-44ce-a574-69adc10cf93a",
                   "name" => "Gameboy Tune",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Tom%C3%A1%C5%A1+Dvo%C5%99%C3%A1k/_/Gameboy+Tune"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "21829902-c427-4eb5-b777-86d252d8591f",
                 title: "Mr. Handagote",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "35ac1700-84f1-4bd9-924b-3792b742e618",
                   name: "Tomáš Dvořák"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "4bad26f6-1b27-4554-93bd-40b91ed7866c",
                   title: "Machinarium Soundtrack"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_592_942,
                 scrobbled_at_label: "03 Nov 2024, 00:15",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "Machinarium Soundtrack",
                     "mbid" => "4bad26f6-1b27-4554-93bd-40b91ed7866c"
                   },
                   "artist" => %{
                     "#text" => "Tomáš Dvořák",
                     "mbid" => "35ac1700-84f1-4bd9-924b-3792b742e618"
                   },
                   "date" => %{"#text" => "03 Nov 2024, 00:15", "uts" => "1730592942"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "21829902-c427-4eb5-b777-86d252d8591f",
                   "name" => "Mr. Handagote",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Tom%C3%A1%C5%A1+Dvo%C5%99%C3%A1k/_/Mr.+Handagote"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "07efe704-e3d3-450f-b64d-906448101aa5",
                 title: "The Mezzanine",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "35ac1700-84f1-4bd9-924b-3792b742e618",
                   name: "Tomáš Dvořák"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "4bad26f6-1b27-4554-93bd-40b91ed7866c",
                   title: "Machinarium Soundtrack"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_592_775,
                 scrobbled_at_label: "03 Nov 2024, 00:12",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "Machinarium Soundtrack",
                     "mbid" => "4bad26f6-1b27-4554-93bd-40b91ed7866c"
                   },
                   "artist" => %{
                     "#text" => "Tomáš Dvořák",
                     "mbid" => "35ac1700-84f1-4bd9-924b-3792b742e618"
                   },
                   "date" => %{"#text" => "03 Nov 2024, 00:12", "uts" => "1730592775"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "07efe704-e3d3-450f-b64d-906448101aa5",
                   "name" => "The Mezzanine",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Tom%C3%A1%C5%A1+Dvo%C5%99%C3%A1k/_/The+Mezzanine"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "09dc71fd-cf8a-4ad7-a3ed-5fd3dd2da143",
                 title: "Nanorobot Tune",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "35ac1700-84f1-4bd9-924b-3792b742e618",
                   name: "Tomáš Dvořák"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "4bad26f6-1b27-4554-93bd-40b91ed7866c",
                   title: "Machinarium Soundtrack"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_587_431,
                 scrobbled_at_label: "02 Nov 2024, 22:43",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "Machinarium Soundtrack",
                     "mbid" => "4bad26f6-1b27-4554-93bd-40b91ed7866c"
                   },
                   "artist" => %{
                     "#text" => "Tomáš Dvořák",
                     "mbid" => "35ac1700-84f1-4bd9-924b-3792b742e618"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 22:43", "uts" => "1730587431"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "09dc71fd-cf8a-4ad7-a3ed-5fd3dd2da143",
                   "name" => "Nanorobot Tune",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Tom%C3%A1%C5%A1+Dvo%C5%99%C3%A1k/_/Nanorobot+Tune"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "03a99f77-9da7-314b-8fdb-bfe1f3e9f6e6",
                 title: "Clockwise Operetta",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "35ac1700-84f1-4bd9-924b-3792b742e618",
                   name: "Tomáš Dvořák"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "4bad26f6-1b27-4554-93bd-40b91ed7866c",
                   title: "Machinarium Soundtrack"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_587_213,
                 scrobbled_at_label: "02 Nov 2024, 22:40",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "Machinarium Soundtrack",
                     "mbid" => "4bad26f6-1b27-4554-93bd-40b91ed7866c"
                   },
                   "artist" => %{
                     "#text" => "Tomáš Dvořák",
                     "mbid" => "35ac1700-84f1-4bd9-924b-3792b742e618"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 22:40", "uts" => "1730587213"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "03a99f77-9da7-314b-8fdb-bfe1f3e9f6e6",
                   "name" => "Clockwise Operetta",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Tom%C3%A1%C5%A1+Dvo%C5%99%C3%A1k/_/Clockwise+Operetta"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "3525dfb3-fe86-4295-a1ad-332f00d7239a",
                 title: "The Sea",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "35ac1700-84f1-4bd9-924b-3792b742e618",
                   name: "Tomáš Dvořák"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "4bad26f6-1b27-4554-93bd-40b91ed7866c",
                   title: "Machinarium Soundtrack"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_586_978,
                 scrobbled_at_label: "02 Nov 2024, 22:36",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "Machinarium Soundtrack",
                     "mbid" => "4bad26f6-1b27-4554-93bd-40b91ed7866c"
                   },
                   "artist" => %{
                     "#text" => "Tomáš Dvořák",
                     "mbid" => "35ac1700-84f1-4bd9-924b-3792b742e618"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 22:36", "uts" => "1730586978"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "3525dfb3-fe86-4295-a1ad-332f00d7239a",
                   "name" => "The Sea",
                   "streamable" => "0",
                   "url" => "https://www.last.fm/music/Tom%C3%A1%C5%A1+Dvo%C5%99%C3%A1k/_/The+Sea"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "2e468dc8-8734-42af-a820-201ab92835a7",
                 title: "The Bottom",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "35ac1700-84f1-4bd9-924b-3792b742e618",
                   name: "Tomáš Dvořák"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "4bad26f6-1b27-4554-93bd-40b91ed7866c",
                   title: "Machinarium Soundtrack"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_586_696,
                 scrobbled_at_label: "02 Nov 2024, 22:31",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "Machinarium Soundtrack",
                     "mbid" => "4bad26f6-1b27-4554-93bd-40b91ed7866c"
                   },
                   "artist" => %{
                     "#text" => "Tomáš Dvořák",
                     "mbid" => "35ac1700-84f1-4bd9-924b-3792b742e618"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 22:31", "uts" => "1730586696"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "2e468dc8-8734-42af-a820-201ab92835a7",
                   "name" => "The Bottom",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Tom%C3%A1%C5%A1+Dvo%C5%99%C3%A1k/_/The+Bottom"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "",
                 title: "The South Atlantic",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "",
                   name: "Public Service Broadcasting feat. This Is The Kit"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_583_124,
                 scrobbled_at_label: "02 Nov 2024, 21:32",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting feat. This Is The Kit",
                     "mbid" => ""
                   },
                   "date" => %{"#text" => "02 Nov 2024, 21:32", "uts" => "1730583124"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "",
                   "name" => "The South Atlantic",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Public+Service+Broadcasting+feat.+This+Is+The+Kit/_/The+South+Atlantic"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "",
                 title: "The Fun Of It",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "",
                   name: "Public Service Broadcasting feat. Andreya Casablanca"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_582_915,
                 scrobbled_at_label: "02 Nov 2024, 21:28",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting feat. Andreya Casablanca",
                     "mbid" => ""
                   },
                   "date" => %{"#text" => "02 Nov 2024, 21:28", "uts" => "1730582915"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "",
                   "name" => "The Fun Of It",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Public+Service+Broadcasting+feat.+Andreya+Casablanca/_/The+Fun+Of+It"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "77719694-4c4a-4bb6-a20e-5852b3166b34",
                 title: "Towards The Dawn",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d",
                   name: "Public Service Broadcasting"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_582_721,
                 scrobbled_at_label: "02 Nov 2024, 21:25",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting",
                     "mbid" => "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 21:25", "uts" => "1730582721"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "77719694-4c4a-4bb6-a20e-5852b3166b34",
                   "name" => "Towards The Dawn",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Public+Service+Broadcasting/_/Towards+The+Dawn"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "",
                 title: "I Was Always Dreaming",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d",
                   name: "Public Service Broadcasting"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_582_531,
                 scrobbled_at_label: "02 Nov 2024, 21:22",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting",
                     "mbid" => "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 21:22", "uts" => "1730582531"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "",
                   "name" => "I Was Always Dreaming",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Public+Service+Broadcasting/_/I+Was+Always+Dreaming"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "",
                 title: "Howland",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d",
                   name: "Public Service Broadcasting"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_582_162,
                 scrobbled_at_label: "02 Nov 2024, 21:16",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting",
                     "mbid" => "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 21:16", "uts" => "1730582162"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "",
                   "name" => "Howland",
                   "streamable" => "0",
                   "url" => "https://www.last.fm/music/Public+Service+Broadcasting/_/Howland"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "",
                 title: "A Different Kind Of Love",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "",
                   name: "Public Service Broadcasting Feat. EERA"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_581_791,
                 scrobbled_at_label: "02 Nov 2024, 21:09",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting Feat. EERA",
                     "mbid" => ""
                   },
                   "date" => %{"#text" => "02 Nov 2024, 21:09", "uts" => "1730581791"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "",
                   "name" => "A Different Kind Of Love",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Public+Service+Broadcasting+Feat.+EERA/_/A+Different+Kind+Of+Love"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "",
                 title: "Monsoons",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d",
                   name: "Public Service Broadcasting"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_581_574,
                 scrobbled_at_label: "02 Nov 2024, 21:06",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting",
                     "mbid" => "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 21:06", "uts" => "1730581574"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "",
                   "name" => "Monsoons",
                   "streamable" => "0",
                   "url" => "https://www.last.fm/music/Public+Service+Broadcasting/_/Monsoons"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "",
                 title: "Arabian Flight",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d",
                   name: "Public Service Broadcasting"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_581_335,
                 scrobbled_at_label: "02 Nov 2024, 21:02",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting",
                     "mbid" => "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 21:02", "uts" => "1730581335"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "",
                   "name" => "Arabian Flight",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Public+Service+Broadcasting/_/Arabian+Flight"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "6b61f1d9-0323-43f3-a85e-b57e5094bbaf",
                 title: "Electra",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d",
                   name: "Public Service Broadcasting"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_581_095,
                 scrobbled_at_label: "02 Nov 2024, 20:58",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting",
                     "mbid" => "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 20:58", "uts" => "1730581095"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "6b61f1d9-0323-43f3-a85e-b57e5094bbaf",
                   "name" => "Electra",
                   "streamable" => "0",
                   "url" => "https://www.last.fm/music/Public+Service+Broadcasting/_/Electra"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "",
                 title: "The South Atlantic",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "",
                   name: "Public Service Broadcasting feat. This Is The Kit"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_580_883,
                 scrobbled_at_label: "02 Nov 2024, 20:54",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting feat. This Is The Kit",
                     "mbid" => ""
                   },
                   "date" => %{"#text" => "02 Nov 2024, 20:54", "uts" => "1730580883"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "",
                   "name" => "The South Atlantic",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Public+Service+Broadcasting+feat.+This+Is+The+Kit/_/The+South+Atlantic"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "",
                 title: "The Fun Of It",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "",
                   name: "Public Service Broadcasting feat. Andreya Casablanca"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_580_673,
                 scrobbled_at_label: "02 Nov 2024, 20:51",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting feat. Andreya Casablanca",
                     "mbid" => ""
                   },
                   "date" => %{"#text" => "02 Nov 2024, 20:51", "uts" => "1730580673"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "",
                   "name" => "The Fun Of It",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Public+Service+Broadcasting+feat.+Andreya+Casablanca/_/The+Fun+Of+It"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "77719694-4c4a-4bb6-a20e-5852b3166b34",
                 title: "Towards The Dawn",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d",
                   name: "Public Service Broadcasting"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_580_481,
                 scrobbled_at_label: "02 Nov 2024, 20:48",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting",
                     "mbid" => "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 20:48", "uts" => "1730580481"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "77719694-4c4a-4bb6-a20e-5852b3166b34",
                   "name" => "Towards The Dawn",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Public+Service+Broadcasting/_/Towards+The+Dawn"
                 }
               },
               %LastFm.Track{
                 musicbrainz_id: "",
                 title: "I Was Always Dreaming",
                 artist: %LastFm.Artist{
                   musicbrainz_id: "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d",
                   name: "Public Service Broadcasting"
                 },
                 album: %LastFm.Album{
                   musicbrainz_id: "2157367e-bf73-48bb-8185-41023a54fa08",
                   title: "The Last Flight"
                 },
                 cover_url:
                   "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_580_290,
                 scrobbled_at_label: "02 Nov 2024, 20:44",
                 last_fm_data: %{
                   "album" => %{
                     "#text" => "The Last Flight",
                     "mbid" => "2157367e-bf73-48bb-8185-41023a54fa08"
                   },
                   "artist" => %{
                     "#text" => "Public Service Broadcasting",
                     "mbid" => "93834e82-3a0b-4ec2-a2e4-6eca0a497e6d"
                   },
                   "date" => %{"#text" => "02 Nov 2024, 20:44", "uts" => "1730580290"},
                   "image" => [
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "small"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/64s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "medium"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/174s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "large"
                     },
                     %{
                       "#text" =>
                         "https://lastfm.freetls.fastly.net/i/u/300x300/7272b50a02fb3e35c59376d2f96cad97.jpg",
                       "size" => "extralarge"
                     }
                   ],
                   "mbid" => "",
                   "name" => "I Was Always Dreaming",
                   "streamable" => "0",
                   "url" =>
                     "https://www.last.fm/music/Public+Service+Broadcasting/_/I+Was+Always+Dreaming"
                 }
               }
             ] == LastFm.Track.from_api_response(api_response)
    end
  end
end
