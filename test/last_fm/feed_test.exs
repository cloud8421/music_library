defmodule LastFm.FeedTest do
  use MusicLibrary.DataCase

  alias LastFm.{Album, Artist, Feed, Track}

  @track_one %Track{
    musicbrainz_id: "5689211e-9afa-3c3e-8e34-63dc0de45ef1",
    title: "The Flow",
    artist: %Artist{
      musicbrainz_id: "0cf0af1f-20ca-4863-9b24-5f52772f7715",
      name: "Anekdoten"
    },
    album: %Album{
      musicbrainz_id: "08237599-8fdf-4e2b-a7c9-eb5336f60346",
      title: "Vemod"
    },
    cover_url: "https://lastfm.freetls.fastly.net/i/u/64s/9741e297b9884a4294624f0f90e14749.jpg",
    scrobbled_at_uts: 1_731_318_211,
    scrobbled_at_label: "11 Nov 2024, 09:43",
    last_fm_data: %{}
  }
  @track_two %Track{
    musicbrainz_id: "619cb295-b155-3e35-b65a-396a7cd1fc47",
    title: "Wheel",
    artist: %Artist{
      musicbrainz_id: "0cf0af1f-20ca-4863-9b24-5f52772f7715",
      name: "Anekdoten"
    },
    album: %Album{
      musicbrainz_id: "08237599-8fdf-4e2b-a7c9-eb5336f60346",
      title: "Vemod"
    },
    cover_url: "https://lastfm.freetls.fastly.net/i/u/64s/9741e297b9884a4294624f0f90e14749.jpg",
    scrobbled_at_uts: 1_731_318_945,
    scrobbled_at_label: "11 Nov 2024, 09:55",
    last_fm_data: %{}
  }

  describe "update and broadcast" do
    test "it stores the track and broadcasts the update" do
      :ok = Feed.subscribe()
      :ok = Feed.update([@track_two, @track_one])

      assert_receive %{tracks: [@track_two, @track_one]}
    end

    test "it returns tracks in descending order of scrobble" do
      :ok = Feed.update([@track_two, @track_one])
      track_two_scrobbled_at_uts = @track_two.scrobbled_at_uts
      track_one_scrobbled_at_uts = @track_one.scrobbled_at_uts

      assert [
               %{scrobbled_at_uts: ^track_two_scrobbled_at_uts},
               %{scrobbled_at_uts: ^track_one_scrobbled_at_uts}
             ] = Feed.all_tracks(10)
    end
  end
end
