defmodule MusicLibraryWeb.StatsLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  alias MusicLibrary.{Records, Repo, Wishlist}
  alias MusicBrainz.APIMock
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]
  import MusicLibrary.Fixtures.Records
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicBrainz.Fixtures.Release
  import Mox

  setup :verify_on_exit!

  defp fill_collection(_) do
    records = Enum.map(1..19, fn _ -> record() end)
    %{collection: records}
  end

  defp fill_wishlist(_) do
    records = Enum.map(1..21, fn _ -> record(%{purchased_at: nil}) end)
    %{wishlist: records}
  end

  describe "Stats home page" do
    setup [:fill_collection, :fill_wishlist]

    test "it shows the collection counts (total, format, and type)", %{
      conn: conn,
      collection: collection
    } do
      session =
        conn
        |> visit("/")
        |> assert_has("dd", text: collection |> length() |> Integer.to_string())

      collection
      |> Enum.frequencies_by(& &1.format)
      |> Enum.each(fn {format, count} ->
        assert_has(session, "a", text: to_string(count))
        assert_has(session, "dt", text: format_label(format))
      end)

      collection
      |> Enum.frequencies_by(& &1.type)
      |> Enum.each(fn {type, count} ->
        assert_has(session, "a", text: to_string(count))
        assert_has(session, "dt", text: type_label(type))
      end)
    end

    test "it shows the latest purchase", %{conn: conn, collection: collection} do
      # purchased_at has second precision, so finding the latest purchased using then
      # highest purchased_at value doesn't work, as it picks the wrong value.
      latest_record = List.last(collection)

      session =
        conn
        |> visit("/")
        |> assert_has("span", text: escape(latest_record.title))

      for artist <- latest_record.artists do
        assert_has(session, "a", text: escape(artist.name))
      end
    end

    test "it shows the wishlist total count", %{conn: conn, wishlist: wishlist} do
      conn
      |> visit("/")
      |> assert_has("dd", text: wishlist |> length() |> Integer.to_string())
    end

    test "it shows the scrobble activity", %{conn: conn} do
      # In test we don't run the LastFm.Refresh worker,
      # so we need to interact directly with the LastFm.Feed to have some data
      #
      # We use three tracks from three different albums in order to test the three possible states for each track:
      # collected, wishlisted or not tracked.

      machinarium_soundtrack_track = %LastFm.Track{
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
        scrobbled_at_label: "03 Nov 2024, 23:59"
      }

      the_last_flight_track = %LastFm.Track{
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
        scrobbled_at_label: "02 Nov 2024, 21:22"
      }

      the_mystery_of_time_track = %LastFm.Track{
        musicbrainz_id: "276806b9-e525-449f-9ff5-4fbf89719e5b",
        title: "Death Is Just a Feeling (Alt. Version)",
        artist: %LastFm.Artist{
          musicbrainz_id: "2ecbc483-dee4-442f-8ce7-f3ab31c73f87",
          name: "Avantasia"
        },
        album: %LastFm.Album{
          musicbrainz_id: "003d1505-b3ac-4acf-bed1-02e2c8134a26",
          title: "The Mystery of Time: A Rock Epic"
        },
        cover_url:
          "https://lastfm.freetls.fastly.net/i/u/64s/104b3f466df84b67cbbe8eadf503fba4.jpg",
        scrobbled_at_uts: 1_732_103_695,
        scrobbled_at_label: "20 Nov 2024, 11:54"
      }

      in_murmuration_track = %LastFm.Track{
        musicbrainz_id: "",
        title: "Wait For Me",
        artist: %LastFm.Artist{
          musicbrainz_id: "298c6d13-4757-437d-a3a6-07d0b3255e5b",
          name: "Von Hertzen Brothers"
        },
        album: %LastFm.Album{
          musicbrainz_id: "",
          title: "In Murmuration"
        },
        cover_url:
          "https://lastfm.freetls.fastly.net/i/u/64s/f4923850113a5d365b1fd2d04cb4c1c3.jpg",
        scrobbled_at_uts: 1_732_399_832,
        scrobbled_at_label: "23 Nov 2024, 22:10"
      }

      LastFm.Feed.update([
        machinarium_soundtrack_track,
        the_last_flight_track,
        the_mystery_of_time_track,
        in_murmuration_track
      ])

      # We add one album to the wishlist, and one to the collection so that
      # their status in the scrobble activity changes.

      _machinarium_soundtrack =
        record(purchased_at: nil)
        |> Records.change_record(%{release_ids: ["4bad26f6-1b27-4554-93bd-40b91ed7866c"]})
        |> Repo.update!()

      _the_last_flight =
        record(purchased_at: DateTime.utc_now())
        |> Records.change_record(%{release_ids: ["2157367e-bf73-48bb-8185-41023a54fa08"]})
        |> Repo.update!()

      session =
        conn
        |> visit("/")
        |> assert_has("#track-#{machinarium_soundtrack_track.scrobbled_at_uts}",
          text: "Wishlisted"
        )
        |> assert_has("#track-#{the_last_flight_track.scrobbled_at_uts}", text: "Collected")
        |> assert_has("#track-#{the_mystery_of_time_track.scrobbled_at_uts}",
          text: "Choose which format to import"
        )
        |> assert_has("#track-#{in_murmuration_track.scrobbled_at_uts}",
          text: "No MB ID"
        )

      # We now try to import The Mystery of Time.

      release = release(:mystery_of_time)
      release_id = release_id(:mystery_of_time)

      release_group = release_group(:mystery_of_time)
      release_group_id = release_group_id(:mystery_of_time)

      expect(APIMock, :get_release, fn ^release_id, _config ->
        {:ok, release}
      end)

      expect(APIMock, :get_release_group, fn ^release_group_id, _config ->
        {:ok, release_group}
      end)

      expect(APIMock, :get_releases, fn ^release_group_id, _opts, _config ->
        {:ok, %{"releases" => release_group["releases"]}}
      end)

      # Doesn't matter if we use a different cover
      cover_data = File.read!(marbles_cover_fixture())

      expect(APIMock, :get_cover_art, fn {:musicbrainz_id, ^release_group_id}, _config ->
        {:ok, cover_data}
      end)

      assert [] == Wishlist.search_records("mbid:#{release_group_id}")

      session =
        session
        |> click_link(
          "#track-#{the_mystery_of_time_track.scrobbled_at_uts} a",
          "CD"
        )

      assert [wishlisted_record] = Wishlist.search_records("mbid:#{release_group_id}")
      assert_path(session, ~p"/wishlist/#{wishlisted_record.id}")
    end
  end
end
