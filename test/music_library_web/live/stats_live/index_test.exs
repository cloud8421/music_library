defmodule MusicLibraryWeb.StatsLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias MusicLibrary.{Records, Repo, Wishlist}

  defp fill_collection(_) do
    current_time = DateTime.utc_now()

    records =
      Enum.map(1..5, fn i ->
        purchased_at = DateTime.add(current_time, i, :second)
        record(%{purchased_at: purchased_at})
      end)

    %{collection: records}
  end

  defp fill_wishlist(_) do
    records = Enum.map(1..3, fn _ -> record(%{purchased_at: nil}) end)
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
        |> assert_has("dd", collection |> length() |> Integer.to_string())

      collection
      |> Enum.frequencies_by(& &1.format)
      |> Enum.each(fn {format, count} ->
        assert_has(session, "a", to_string(count))
        assert_has(session, "dt", format_label(format))
      end)

      collection
      |> Enum.frequencies_by(& &1.type)
      |> Enum.each(fn {type, count} ->
        assert_has(session, "a", to_string(count))
        assert_has(session, "dt", type_label(type))
      end)
    end

    test "it shows the latest purchase", %{conn: conn, collection: collection} do
      latest_record = List.last(collection)

      session =
        conn
        |> visit("/")
        |> assert_has("span", escape(latest_record.title))

      for artist <- latest_record.artists do
        assert_has(session, "a", escape(artist.name))
      end
    end

    test "it shows the wishlist total count", %{conn: conn, wishlist: wishlist} do
      conn
      |> visit("/")
      |> assert_has("dd", wishlist |> length() |> Integer.to_string())
    end

    test "it displays records for the current date in the 'On This Day' section", %{
      conn: conn,
      collection: collection
    } do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      record_today =
        List.first(collection)
        |> Records.change_record(%{
          release_date: Date.to_iso8601(today),
          purchased_at: DateTime.utc_now()
        })
        |> Repo.update!()

      record_yesterday =
        List.last(collection)
        |> Records.change_record(%{
          release_date: Date.to_iso8601(yesterday),
          purchased_at: DateTime.utc_now()
        })
        |> Repo.update!()

      session = conn |> visit("/")

      assert_has(session, "h1", "On This day")

      assert_has(session, "##{record_today.id} h2", escape(record_today.title))

      refute_has(session, "##{record_yesterday.id} h2", escape(record_yesterday.title))
    end

    test "it updates the 'On This Day' records when the date is changed", %{
      conn: conn,
      collection: collection
    } do
      today = Date.utc_today()
      yesterday = Date.add(today, -1)

      record_today =
        List.first(collection)
        |> Records.change_record(%{
          release_date: Date.to_iso8601(today),
          purchased_at: DateTime.utc_now()
        })
        |> Repo.update!()

      record_yesterday =
        List.last(collection)
        |> Records.change_record(%{
          release_date: Date.to_iso8601(yesterday),
          purchased_at: DateTime.utc_now()
        })
        |> Repo.update!()

      session = conn |> visit("/")

      assert_has(session, "##{record_today.id} h2", escape(record_today.title))

      refute_has(session, "##{record_yesterday.id} h2", escape(record_yesterday.title))

      session
      |> unwrap(fn view ->
        view
        |> form("[phx-change='set_current_date']", %{"current_date" => Date.to_iso8601(yesterday)})
        |> render_change()
      end)

      refute_has(session, "##{record_today.id} h2", escape(record_today.title))

      assert_has(session, "##{record_yesterday.id} h2", escape(record_yesterday.title))
    end
  end

  describe "Scrobble activity" do
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
        scrobbled_at_label: "03 Nov 2024, 23:59",
        last_fm_data: %{}
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
        scrobbled_at_label: "02 Nov 2024, 21:22",
        last_fm_data: %{}
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
        scrobbled_at_label: "20 Nov 2024, 11:54",
        last_fm_data: %{}
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
        scrobbled_at_label: "23 Nov 2024, 22:10",
        last_fm_data: %{}
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

      # By default, we show scrobbled albums

      session =
        conn
        |> visit("/")
        |> assert_has("dd", "4")
        |> assert_has("#album-#{machinarium_soundtrack_track.scrobbled_at_uts}",
          text: "Wishlisted"
        )
        |> assert_has("[hidden] p", machinarium_soundtrack_track.title)
        |> assert_has("p", machinarium_soundtrack_track.album.title)
        |> assert_has("#album-#{the_last_flight_track.scrobbled_at_uts}", "Collected")
        |> assert_has("#album-#{the_mystery_of_time_track.scrobbled_at_uts}",
          text: "Choose which format to import"
        )
        |> assert_has("#album-#{in_murmuration_track.scrobbled_at_uts}",
          text: "No MB ID"
        )
        # Switch to tracks list
        |> click_button("Tracks")
        |> assert_has("#track-#{machinarium_soundtrack_track.scrobbled_at_uts}",
          text: "Wishlisted"
        )
        |> assert_has("p", machinarium_soundtrack_track.title)
        |> assert_has("p", machinarium_soundtrack_track.album.title)
        |> assert_has("#track-#{the_last_flight_track.scrobbled_at_uts}", "Collected")
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
      release_group_releases = release_group_releases(:mystery_of_time)

      cover_data = marbles_cover_data()

      Req.Test.stub(MusicBrainz.API, fn conn ->
        case conn.path_info do
          [_ws, _version, "release-group", ^release_group_id] ->
            Req.Test.json(conn, release_group)

          [_ws, _version, "release", ^release_id] ->
            Req.Test.json(conn, release)

          [_ws, _version, "release"] ->
            Req.Test.json(conn, release_group_releases)

          [_release_group, ^release_group_id, "front"] ->
            Plug.Conn.send_resp(conn, 200, cover_data)
        end
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
