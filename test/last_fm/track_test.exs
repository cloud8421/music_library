defmodule LastFm.TrackTest do
  use ExUnit.Case, async: true

  @api_response_path Path.expand("../support/fixtures/user.getrecenttracks.json", __DIR__)

  describe "from_api_response/1" do
    test "returns correct data" do
      api_response =
        @api_response_path
        |> File.read!()
        |> Jason.decode!()
        |> get_in(["recenttracks", "track"])

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
                   "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_678_348,
                 scrobbled_at_label: "03 Nov 2024, 23:59"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_592_942,
                 scrobbled_at_label: "03 Nov 2024, 00:15"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_592_775,
                 scrobbled_at_label: "03 Nov 2024, 00:12"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_587_431,
                 scrobbled_at_label: "02 Nov 2024, 22:43"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_587_213,
                 scrobbled_at_label: "02 Nov 2024, 22:40"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_586_978,
                 scrobbled_at_label: "02 Nov 2024, 22:36"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/b301ac9a72f14eb4ce3ddd785eb562b2.jpg",
                 scrobbled_at_uts: 1_730_586_696,
                 scrobbled_at_label: "02 Nov 2024, 22:31"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_583_124,
                 scrobbled_at_label: "02 Nov 2024, 21:32"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_582_915,
                 scrobbled_at_label: "02 Nov 2024, 21:28"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_582_721,
                 scrobbled_at_label: "02 Nov 2024, 21:25"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_582_531,
                 scrobbled_at_label: "02 Nov 2024, 21:22"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_582_162,
                 scrobbled_at_label: "02 Nov 2024, 21:16"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_581_791,
                 scrobbled_at_label: "02 Nov 2024, 21:09"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_581_574,
                 scrobbled_at_label: "02 Nov 2024, 21:06"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_581_335,
                 scrobbled_at_label: "02 Nov 2024, 21:02"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_581_095,
                 scrobbled_at_label: "02 Nov 2024, 20:58"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_580_883,
                 scrobbled_at_label: "02 Nov 2024, 20:54"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_580_673,
                 scrobbled_at_label: "02 Nov 2024, 20:51"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_580_481,
                 scrobbled_at_label: "02 Nov 2024, 20:48"
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
                   "https://lastfm.freetls.fastly.net/i/u/34s/7272b50a02fb3e35c59376d2f96cad97.jpg",
                 scrobbled_at_uts: 1_730_580_290,
                 scrobbled_at_label: "02 Nov 2024, 20:44"
               }
             ] ==
               LastFm.Track.from_api_response(api_response)
    end
  end
end
