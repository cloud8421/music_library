defmodule MusicLibraryWeb.StatsLive.IndexTest do
  use MusicLibraryWeb.ConnCase

  import MusicBrainz.Fixtures.Release
  import MusicBrainz.Fixtures.ReleaseGroup
  import MusicLibrary.Fixtures.Records
  import MusicLibraryWeb.RecordComponents, only: [format_label: 1, type_label: 1]

  alias MusicLibrary.{ListeningStats, Records, Repo, Wishlist}

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

    test "shows the collection counts (total, format, and type)", %{
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

    test "shows the latest purchase", %{conn: conn, collection: collection} do
      latest_record = List.last(collection)

      session =
        conn
        |> visit("/")
        |> assert_has("span", escape(latest_record.title))

      for artist <- latest_record.artists do
        assert_has(session, "a", escape(artist.name))
      end
    end

    test "shows the wishlist total count", %{conn: conn, wishlist: wishlist} do
      conn
      |> visit("/")
      |> assert_has("a", wishlist |> length() |> Integer.to_string())
    end

    test "displays records for the current date in the 'On This Day' section", %{
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

      session = conn |> visit("/") |> render_async()

      assert_has(session, "h1", "On This day")

      assert_has(session, "##{record_today.id} h2", escape(record_today.title))

      refute_has(session, "##{record_yesterday.id} h2", escape(record_yesterday.title))
    end

    test "updates the 'On This Day' records when the date is changed", %{
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

      session = conn |> visit("/") |> render_async()

      assert_has(session, "##{record_today.id} h2", escape(record_today.title))

      refute_has(session, "##{record_yesterday.id} h2", escape(record_yesterday.title))

      session
      |> unwrap(fn view ->
        # We simulate clicking on the date picker and picking yesterday - the
        # following event matches the datepicker phx-click attribute
        render_click(view, :set_current_date, %{"current_date" => Date.to_iso8601(yesterday)})
      end)

      refute_has(session, "##{record_today.id} h2", escape(record_today.title))

      assert_has(session, "##{record_yesterday.id} h2", escape(record_yesterday.title))
    end

    test "groups records with the same musicbrainz_id in the 'On This Day' section", %{
      conn: conn,
      collection: collection
    } do
      today = Date.utc_today()

      # Create a record and a duplicate with the same musicbrainz_id
      base_record =
        List.first(collection)
        |> Records.change_record(%{
          release_date: Date.to_iso8601(today),
          purchased_at: DateTime.utc_now()
        })
        |> Repo.update!()

      # Create another record with the SAME musicbrainz_id (different purchase)
      # Convert Artist structs to plain maps for create_record
      artist_maps = Enum.map(base_record.artists, &Map.from_struct/1)

      dup_attrs = %{
        title: base_record.title,
        musicbrainz_id: base_record.musicbrainz_id,
        release_date: Date.to_iso8601(today),
        purchased_at: DateTime.utc_now() |> DateTime.add(1, :second),
        artists: artist_maps,
        genres: base_record.genres,
        format: base_record.format,
        type: base_record.type,
        cover_url: base_record.cover_url,
        cover_hash: base_record.cover_hash,
        musicbrainz_data: base_record.musicbrainz_data
      }

      {:ok, _dup} = MusicLibrary.Records.create_record(dup_attrs)

      session = conn |> visit("/") |> render_async()

      # The grouped record should appear with the group ID
      assert_has(session, "#group-#{base_record.musicbrainz_id}")
      # It should show the release count
      assert_has(session, "#group-#{base_record.musicbrainz_id}", "2 releases")
    end

    test "shows 'Today' label for records released on the current date", %{
      conn: conn,
      collection: collection
    } do
      today = Date.utc_today()

      _record =
        List.first(collection)
        |> Records.change_record(%{
          release_date: Date.to_iso8601(today),
          purchased_at: DateTime.utc_now()
        })
        |> Repo.update!()

      session = conn |> visit("/") |> render_async()

      assert_has(session, "span", "Today")
    end

    test "shows anniversary label for records released exactly 5 years ago", %{
      conn: conn,
      collection: collection
    } do
      today = Date.utc_today()
      # Use year-based adjustment so month-day stays the same
      five_years_ago = %{today | year: today.year - 5}

      _record =
        List.first(collection)
        |> Records.change_record(%{
          release_date: Date.to_iso8601(five_years_ago),
          purchased_at: DateTime.utc_now()
        })
        |> Repo.update!()

      session = conn |> visit("/") |> render_async()

      assert_has(session, "span", "5 years ago")
    end

    test "shows anniversary label for records released exactly 10 years ago", %{
      conn: conn,
      collection: collection
    } do
      today = Date.utc_today()
      # Use year-based adjustment so month-day stays the same
      ten_years_ago = %{today | year: today.year - 10}

      _record =
        List.first(collection)
        |> Records.change_record(%{
          release_date: Date.to_iso8601(ten_years_ago),
          purchased_at: DateTime.utc_now()
        })
        |> Repo.update!()

      session = conn |> visit("/") |> render_async()

      assert_has(session, "span", "10 years ago")
    end

    test "shows normal year label for records not on milestone anniversary", %{
      conn: conn,
      collection: collection
    } do
      today = Date.utc_today()
      # Use year-based adjustment so month-day stays the same
      three_years_ago = %{today | year: today.year - 3}

      _record =
        List.first(collection)
        |> Records.change_record(%{
          release_date: Date.to_iso8601(three_years_ago),
          purchased_at: DateTime.utc_now()
        })
        |> Repo.update!()

      session = conn |> visit("/") |> render_async()

      # 3 years is not a milestone (not divisible by 5 or 10)
      assert_has(session, "span", "3 years ago")
    end
  end

  describe "Scrobble activity" do
    test "shows the scrobble activity", %{conn: conn} do
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

      MusicLibrary.ListeningStats.update([
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

  describe "Daily Scrobble Counts" do
    # Need render/1 for raw HTML assertions (not auto-imported by ConnCase)
    import Phoenix.LiveViewTest, only: [render: 1]

    defp daily_chart_timezone, do: MusicLibrary.default_timezone()

    defp chart_test_date do
      DateTime.utc_now()
      |> DateTime.shift_zone!(daily_chart_timezone())
      |> DateTime.to_date()
      |> Date.add(-1)
    end

    defp chart_label(date) do
      Calendar.strftime(date, "%b %d")
    end

    defp create_chart_track(attrs) do
      date = Keyword.fetch!(attrs, :date)
      offset_seconds = Keyword.get(attrs, :offset_seconds, 0)
      title = Keyword.get_lazy(attrs, :title, &unique_track_title/0)
      timezone = daily_chart_timezone()

      {:ok, date_noon} = DateTime.new(date, ~T[12:00:00], timezone)
      scrobbled_at = DateTime.add(date_noon, offset_seconds, :second)

      %LastFm.Track{
        musicbrainz_id: "test-daily",
        title: title,
        artist: %LastFm.Artist{musicbrainz_id: "", name: "Daily Artist"},
        album: %LastFm.Album{musicbrainz_id: "", title: "Daily Album"},
        cover_url: "https://example.com/daily.jpg",
        scrobbled_at_uts: DateTime.to_unix(scrobbled_at),
        scrobbled_at_label: "test",
        last_fm_data: %{}
      }
    end

    defp insert_chart_tracks(date, count) do
      tracks =
        Enum.map(1..count, fn index ->
          create_chart_track(
            date: date,
            offset_seconds: index,
            title: unique_track_title(index)
          )
        end)

      assert {:ok, ^count} = ListeningStats.update(tracks)

      tracks
    end

    defp unique_track_title(suffix \\ nil) do
      unique = System.unique_integer([:positive])

      case suffix do
        nil -> "Test Daily Track #{unique}"
        suffix -> "Test Daily Track #{suffix}-#{unique}"
      end
    end

    defp assert_daily_chart_count(session, label, expected_count) do
      chart_datums =
        session.view
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.query(
          ~s(#daily-scrobble-counts [data-chart-label="#{label}"][data-chart-value="#{expected_count}"])
        )

      assert Enum.count_until(chart_datums, 2) == 1

      session
    end

    test "renders the daily scrobble counts section before scrobble activity", %{conn: conn} do
      chart_date = chart_test_date()
      insert_chart_tracks(chart_date, 1)

      session = conn |> visit("/")

      assert_has(session, "#daily-scrobble-counts h1", "Daily Scrobbles")
    end

    test "renders with correct date labels and counts", %{conn: conn} do
      chart_date = chart_test_date()
      insert_chart_tracks(chart_date, 2)

      session = conn |> visit("/")

      assert_daily_chart_count(session, chart_label(chart_date), 2)
    end

    test "refreshes daily counts when listening stats update notification is received", %{
      conn: conn
    } do
      chart_date = chart_test_date()
      insert_chart_tracks(chart_date, 1)

      session = conn |> visit("/")
      label = chart_label(chart_date)

      assert_daily_chart_count(session, label, 1)

      new_track = create_chart_track(date: chart_date, offset_seconds: 60)

      assert {:ok, 1} = ListeningStats.update([new_track])
      assert_daily_chart_count(session, label, 2)
    end

    test "appears before scrobble activity in DOM order", %{conn: conn} do
      chart_date = chart_test_date()
      insert_chart_tracks(chart_date, 1)

      session = conn |> visit("/")
      html = render(session.view)

      # daily-scrobble-counts must appear before scrobble-activity in the HTML
      assert html =~ ~r/daily-scrobble-counts.*scrobble-activity/s
    end
  end
end
