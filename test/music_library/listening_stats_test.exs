defmodule MusicLibrary.ListeningStatsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.ArtistInfoFixtures
  import MusicLibrary.ScrobbledTracksFixtures

  alias LastFm.Track
  alias MusicLibrary.Fixtures.Records, as: RecordsFixtures
  alias MusicLibrary.ListeningStats
  alias MusicLibrary.Records.Record

  describe "update/1 and subscribe/0" do
    test "stores tracks and broadcasts the updated track count" do
      :ok = ListeningStats.subscribe()

      track_one = %Track{
        musicbrainz_id: "5689211e-9afa-3c3e-8e34-63dc0de45ef1",
        title: "The Flow",
        artist: %LastFm.Artist{
          musicbrainz_id: "0cf0af1f-20ca-4863-9b24-5f52772f7715",
          name: "Anekdoten"
        },
        album: %LastFm.Album{
          musicbrainz_id: "08237599-8fdf-4e2b-a7c9-eb5336f60346",
          title: "Vemod"
        },
        cover_url:
          "https://lastfm.freetls.fastly.net/i/u/64s/9741e297b9884a4294624f0f90e14749.jpg",
        scrobbled_at_uts: 1_731_318_211,
        scrobbled_at_label: "11 Nov 2024, 09:43",
        last_fm_data: %{}
      }

      track_two = %Track{
        musicbrainz_id: "619cb295-b155-3e35-b65a-396a7cd1fc47",
        title: "Wheel",
        artist: %LastFm.Artist{
          musicbrainz_id: "0cf0af1f-20ca-4863-9b24-5f52772f7715",
          name: "Anekdoten"
        },
        album: %LastFm.Album{
          musicbrainz_id: "08237599-8fdf-4e2b-a7c9-eb5336f60346",
          title: "Vemod"
        },
        cover_url:
          "https://lastfm.freetls.fastly.net/i/u/64s/9741e297b9884a4294624f0f90e14749.jpg",
        scrobbled_at_uts: 1_731_318_945,
        scrobbled_at_label: "11 Nov 2024, 09:55",
        last_fm_data: %{}
      }

      assert {:ok, 2} == ListeningStats.update([track_two, track_one])
      assert_receive %{track_count: 2}

      # Tracks have already been inserted, count of new tracks is 0
      assert {:ok, 0} == ListeningStats.update([track_two, track_one])
      assert_receive %{track_count: 0}
    end
  end

  describe "scrobble_count/0" do
    test "returns correct count" do
      initial_count = ListeningStats.scrobble_count()

      create_test_tracks(3)

      new_count = ListeningStats.scrobble_count()

      assert new_count == initial_count + 3
    end
  end

  describe "list_tracks/1" do
    test "returns all tracks when no parameters provided" do
      _track1 = track_fixture(%{title: "First Track"})
      _track2 = track_fixture(%{title: "Second Track"})

      tracks = list_tracks()

      assert Enum.count_until(tracks, 3) == 2
      track_titles = Enum.map(tracks, & &1.title)
      assert "First Track" in track_titles
      assert "Second Track" in track_titles
    end

    test "returns tracks ordered by scrobbled_at_uts by default" do
      _older_track =
        track_fixture(%{
          title: "Older Track",
          scrobbled_at_uts: System.system_time(:second) - 3600
        })

      _newer_track =
        track_fixture(%{
          title: "Newer Track",
          scrobbled_at_uts: System.system_time(:second)
        })

      assert [track1, track2] = list_tracks(%{order: :scrobbled_at})

      # Should be ordered by scrobbled_at_uts descending (newest first)
      assert track1.title == "Newer Track"
      assert track2.title == "Older Track"
    end

    test "returns tracks ordered by title" do
      track_fixture(%{title: "Zebra Track"})
      track_fixture(%{title: "Alpha Track"})

      assert [track1, track2] = list_tracks(%{order: :title})

      assert track1.title == "Alpha Track"
      assert track2.title == "Zebra Track"
    end

    test "returns tracks ordered by artist name" do
      track_fixture(%{artist_name: "Zebra Artist", title: "Track 1"})
      track_fixture(%{artist_name: "Alpha Artist", title: "Track 2"})

      assert [track1, track2] = list_tracks(%{order: :artist})

      assert track1.artist.name == "Alpha Artist"
      assert track2.artist.name == "Zebra Artist"
    end

    test "returns tracks ordered by album title" do
      track_fixture(%{album_title: "Zebra Album", title: "Track 1"})
      track_fixture(%{album_title: "Alpha Album", title: "Track 2"})

      assert [track1, track2] = list_tracks(%{order: :album})

      assert track1.album.title == "Alpha Album"
      assert track2.album.title == "Zebra Album"
    end

    test "filters tracks by search query matching track title" do
      track_fixture(%{title: "Special Track"})
      track_fixture(%{title: "Regular Track"})

      tracks = list_tracks(%{query: "Special"})

      assert Enum.count_until(tracks, 2) == 1
      assert List.first(tracks).title == "Special Track"
    end

    test "filters tracks by search query matching artist name" do
      track_fixture(%{artist_name: "Special Artist", title: "Track 1"})
      track_fixture(%{artist_name: "Regular Artist", title: "Track 2"})

      tracks = list_tracks(%{query: "Special Artist"})

      assert Enum.count_until(tracks, 2) == 1
      assert List.first(tracks).artist.name == "Special Artist"
    end

    test "filters tracks by search query matching album title" do
      track_fixture(%{album_title: "Special Album", title: "Track 1"})
      track_fixture(%{album_title: "Regular Album", title: "Track 2"})

      tracks = list_tracks(%{query: "Special Album"})

      assert Enum.count_until(tracks, 2) == 1
      assert List.first(tracks).album.title == "Special Album"
    end

    test "applies pagination correctly" do
      create_test_tracks(5)

      # Get first 2 tracks
      tracks_page_1 = list_tracks(%{page: 1, page_size: 2})
      assert Enum.count_until(tracks_page_1, 3) == 2

      # Get next 2 tracks
      tracks_page_2 = list_tracks(%{page: 2, page_size: 2})
      assert Enum.count_until(tracks_page_2, 3) == 2

      # Ensure they're different tracks
      page_1_ids = Enum.map(tracks_page_1, & &1.scrobbled_at_uts)
      page_2_ids = Enum.map(tracks_page_2, & &1.scrobbled_at_uts)
      assert Enum.empty?(page_1_ids -- (page_1_ids -- page_2_ids))
    end

    test "returns empty list when query matches no tracks" do
      track_fixture(%{title: "Test Track"})

      tracks = list_tracks(%{query: "NonexistentTrack"})

      assert tracks == []
    end
  end

  describe "get_track!/1" do
    test "returns the track with given scrobbled_at_uts as integer" do
      track = track_fixture()

      found_track = ListeningStats.get_track!(track.scrobbled_at_uts)

      assert found_track.scrobbled_at_uts == track.scrobbled_at_uts
      assert found_track.title == track.title
    end

    test "returns the track with given scrobbled_at_uts as string" do
      track = track_fixture()

      found_track = ListeningStats.get_track!(to_string(track.scrobbled_at_uts))

      assert found_track.scrobbled_at_uts == track.scrobbled_at_uts
    end

    test "raises Ecto.NoResultsError when track does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        ListeningStats.get_track!(999_999_999)
      end
    end

    test "raises Ecto.NoResultsError when given invalid string" do
      assert_raise Ecto.NoResultsError, fn ->
        ListeningStats.get_track!("invalid")
      end
    end
  end

  describe "update_track/2" do
    test "updates the track with valid attributes" do
      track = track_fixture(%{title: "Original Title"})

      update_attrs = %{
        title: "Updated Title",
        artist: %{name: "Updated Artist"},
        album: %{title: "Updated Album"}
      }

      assert {:ok, updated_track} = ListeningStats.update_track(track, update_attrs)
      assert updated_track.title == "Updated Title"
      assert updated_track.artist.name == "Updated Artist"
      assert updated_track.album.title == "Updated Album"
    end

    test "returns error changeset with invalid attributes" do
      track = track_fixture()

      invalid_attrs = %{title: ""}

      assert {:error, %Ecto.Changeset{}} = ListeningStats.update_track(track, invalid_attrs)
    end

    test "updates scrobbled_at_label" do
      track = track_fixture(%{scrobbled_at_label: "01/01/2024 12:00:00"})

      update_attrs = %{scrobbled_at_label: "02/02/2024 14:30:00"}

      assert {:ok, updated_track} = ListeningStats.update_track(track, update_attrs)
      assert updated_track.scrobbled_at_label == "02/02/2024 14:30:00"
    end

    test "updates cover_url" do
      track = track_fixture(%{cover_url: "https://example.com/old.jpg"})

      update_attrs = %{cover_url: "https://example.com/new.jpg"}

      assert {:ok, updated_track} = ListeningStats.update_track(track, update_attrs)
      assert updated_track.cover_url == "https://example.com/new.jpg"
    end
  end

  describe "delete_track/1" do
    test "deletes the track" do
      track = track_fixture()

      assert {:ok, %Track{}} = ListeningStats.delete_track(track)

      assert_raise Ecto.NoResultsError, fn ->
        ListeningStats.get_track!(track.scrobbled_at_uts)
      end
    end

    test "raises when track has already been deleted" do
      track = track_fixture()
      {:ok, _} = ListeningStats.delete_track(track)

      # Attempt to delete again should fail
      assert_raise Ecto.StaleEntryError, fn ->
        ListeningStats.delete_track(track)
      end
    end
  end

  describe "search_tracks_count/1" do
    test "returns total count when no query provided" do
      create_test_tracks(3)

      count = ListeningStats.search_tracks_count()

      assert count == 3
    end

    test "returns filtered count when query provided" do
      track_fixture(%{title: "Special Track"})
      track_fixture(%{title: "Regular Track"})
      track_fixture(%{title: "Another Track"})

      count = ListeningStats.search_tracks_count("Special")

      assert count == 1
    end

    test "returns zero when query matches no tracks" do
      track_fixture(%{title: "Test Track"})

      count = ListeningStats.search_tracks_count("Nonexistent")

      assert count == 0
    end

    test "counts tracks matching artist name" do
      track_fixture(%{artist_name: "Special Artist", title: "Track 1"})
      track_fixture(%{artist_name: "Regular Artist", title: "Track 2"})

      count = ListeningStats.search_tracks_count("Special")

      assert count == 1
    end

    test "counts tracks matching album title" do
      track_fixture(%{album_title: "Special Album", title: "Track 1"})
      track_fixture(%{album_title: "Regular Album", title: "Track 2"})

      count = ListeningStats.search_tracks_count("Special")

      assert count == 1
    end
  end

  describe "deduplication when multiple records share a release group" do
    setup do
      # Create two collected records that share the same release group
      # (musicbrainz_id) but may have different physical release IDs.
      # The matching_records query groups by release group, so both records
      # should appear for any scrobble matching either record's release IDs.
      shared_musicbrainz_id = Ecto.UUID.generate()

      record_a =
        RecordsFixtures.record(%{
          title: "Marbles Copy A",
          musicbrainz_id: shared_musicbrainz_id
        })

      record_b =
        RecordsFixtures.record(%{
          title: "Marbles Copy B",
          musicbrainz_id: shared_musicbrainz_id
        })

      # Pick a release_id from the marbles fixture (shared by both records
      # since they use the same musicbrainz_data)
      shared_release_id = "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608"
      now = System.system_time(:second)

      track_fixture(%{
        title: "The Invisible Man",
        album_title: "Marbles",
        album_musicbrainz_id: shared_release_id,
        artist_name: "Marillion",
        scrobbled_at_uts: now - 100
      })

      track_fixture(%{
        title: "You're Gone",
        album_title: "Marbles",
        album_musicbrainz_id: shared_release_id,
        artist_name: "Marillion",
        scrobbled_at_uts: now - 200
      })

      expected_record_id = Enum.min([record_a.id, record_b.id])

      %{
        record_a: record_a,
        record_b: record_b,
        expected_record_id: expected_record_id,
        shared_release_id: shared_release_id
      }
    end

    test "list_tracks returns one row per track", %{expected_record_id: expected_record_id} do
      tracks = ListeningStats.list_tracks()

      titles = Enum.map(tracks, & &1.track.title)

      assert Enum.count(titles) == Enum.count(Enum.uniq(titles)),
             "list_tracks returned duplicate rows"

      for result <- tracks do
        assert Enum.count_until(result.matching_records, 3) == 2

        record_ids = Enum.map(result.matching_records, & &1.id)
        assert expected_record_id in record_ids
      end
    end

    test "recent_activity returns one row per track", %{expected_record_id: expected_record_id} do
      %{recent_tracks: recent_tracks} =
        ListeningStats.recent_activity("Etc/UTC", 20)

      titles = Enum.map(recent_tracks, & &1.track.title)

      assert Enum.count(titles) == Enum.count(Enum.uniq(titles)),
             "recent_activity returned duplicate rows"

      for result <- recent_tracks do
        assert Enum.count_until(result.matching_records, 3) == 2

        record_ids = Enum.map(result.matching_records, & &1.id)
        assert expected_record_id in record_ids
      end
    end

    test "get_top_albums returns one entry per album", %{expected_record_id: expected_record_id} do
      results = ListeningStats.get_top_albums(limit: 10)

      marbles_entries = Enum.filter(results, fn r -> r.album_title == "Marbles" end)

      assert Enum.count_until(marbles_entries, 2) == 1,
             "get_top_albums returned duplicate album entries"

      [entry] = marbles_entries
      assert entry.play_count == 2

      record_ids = Enum.map(entry.matching_records, & &1.id)
      assert expected_record_id in record_ids
    end

    test "recent_activity returns matching_records list with all records in release group",
         %{shared_release_id: _shared_release_id} do
      %{recent_tracks: recent_tracks} =
        ListeningStats.recent_activity("Etc/UTC", 20)

      for result <- recent_tracks do
        assert is_list(result.matching_records)
        assert Enum.count_until(result.matching_records, 3) == 2

        for record <- result.matching_records do
          assert Map.has_key?(record, :id)
          assert Map.has_key?(record, :title)
          assert Map.has_key?(record, :format)
          assert Map.has_key?(record, :type)
          assert Map.has_key?(record, :purchased_at)
          assert Map.has_key?(record, :cover_hash)
        end

        # All records should be collected (purchased_at is set by the fixture)
        assert Enum.all?(result.matching_records, & &1.purchased_at)
      end
    end
  end

  describe "matching_records with mixed collected and wishlisted" do
    setup do
      shared_musicbrainz_id = Ecto.UUID.generate()

      collected =
        RecordsFixtures.record(%{
          title: "Marbles CD",
          format: :cd,
          musicbrainz_id: shared_musicbrainz_id
        })

      wishlisted =
        RecordsFixtures.record(%{
          title: "Marbles Vinyl",
          format: :vinyl,
          musicbrainz_id: shared_musicbrainz_id,
          purchased_at: nil
        })

      shared_release_id = "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608"

      track_fixture(%{
        title: "The Invisible Man",
        album_title: "Marbles",
        album_musicbrainz_id: shared_release_id,
        artist_name: "Marillion",
        scrobbled_at_uts: System.system_time(:second) - 100
      })

      %{collected: collected, wishlisted: wishlisted}
    end

    test "recent_activity includes both collected and wishlisted records",
         %{collected: collected, wishlisted: wishlisted} do
      %{recent_tracks: recent_tracks} =
        ListeningStats.recent_activity("Etc/UTC", 20)

      [result] = recent_tracks

      assert Enum.count_until(result.matching_records, 3) == 2

      record_ids = Enum.map(result.matching_records, & &1.id)
      assert collected.id in record_ids
      assert wishlisted.id in record_ids

      collected_record = Enum.find(result.matching_records, &(&1.id == collected.id))
      assert collected_record.purchased_at

      wishlisted_record = Enum.find(result.matching_records, &(&1.id == wishlisted.id))
      refute wishlisted_record.purchased_at
    end

    test "get_top_albums includes both collected and wishlisted records",
         %{collected: collected, wishlisted: wishlisted} do
      results = ListeningStats.get_top_albums(limit: 10)

      marbles_entries = Enum.filter(results, fn r -> r.album_title == "Marbles" end)
      assert Enum.count_until(marbles_entries, 2) == 1

      [entry] = marbles_entries
      assert Enum.count_until(entry.matching_records, 3) == 2

      record_ids = Enum.map(entry.matching_records, & &1.id)
      assert collected.id in record_ids
      assert wishlisted.id in record_ids
    end
  end

  describe "matching_records deterministic ordering" do
    setup do
      shared_musicbrainz_id = Ecto.UUID.generate()
      shared_release_id = "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608"

      collected_a =
        RecordsFixtures.record(%{
          title: "Marbles CD",
          format: :cd,
          musicbrainz_id: shared_musicbrainz_id
        })

      collected_b =
        RecordsFixtures.record(%{
          title: "Marbles Vinyl",
          format: :vinyl,
          musicbrainz_id: shared_musicbrainz_id
        })

      wishlisted_a =
        RecordsFixtures.record(%{
          title: "Marbles Blu-ray",
          format: :blu_ray,
          musicbrainz_id: shared_musicbrainz_id,
          purchased_at: nil
        })

      wishlisted_b =
        RecordsFixtures.record(%{
          title: "Marbles DVD",
          format: :dvd,
          musicbrainz_id: shared_musicbrainz_id,
          purchased_at: nil
        })

      now = System.system_time(:second)

      track_fixture(%{
        title: "The Invisible Man",
        album_title: "Marbles",
        album_musicbrainz_id: shared_release_id,
        artist_name: "Marillion",
        scrobbled_at_uts: now - 100
      })

      collected_ids =
        [collected_a.id, collected_b.id]
        |> Enum.sort()

      wishlisted_ids =
        [wishlisted_a.id, wishlisted_b.id]
        |> Enum.sort()

      expected_ids = collected_ids ++ wishlisted_ids

      %{expected_ids: expected_ids}
    end

    test "list_tracks matching_records are collected-first then id-ordered",
         %{expected_ids: expected_ids} do
      results = ListeningStats.list_tracks()
      assert Enum.count_until(results, 2) == 1

      [result] = results
      assert Enum.map(result.matching_records, & &1.id) == expected_ids
    end

    test "recent_activity matching_records are collected-first then id-ordered",
         %{expected_ids: expected_ids} do
      %{recent_tracks: recent_tracks} = ListeningStats.recent_activity("Etc/UTC", 20)
      assert Enum.count_until(recent_tracks, 2) == 1

      [result] = recent_tracks
      assert Enum.map(result.matching_records, & &1.id) == expected_ids
    end

    test "get_top_albums matching_records are collected-first then id-ordered",
         %{expected_ids: expected_ids} do
      results = ListeningStats.get_top_albums(limit: 10)

      marbles_entries = Enum.filter(results, fn r -> r.album_title == "Marbles" end)
      assert Enum.count_until(marbles_entries, 2) == 1

      [entry] = marbles_entries
      assert Enum.map(entry.matching_records, & &1.id) == expected_ids
    end
  end

  describe "play_count uses count(DISTINCT scrobbled_at_uts)" do
    test "two tracks at the same scrobbled_at_uts count as one play in get_top_albums" do
      shared_uts = System.system_time(:second) - 100

      # Two distinct rows (different titles, so the (uts, title) UNIQUE
      # constraint is satisfied) sharing the same scrobble timestamp.
      # Last.fm sometimes scrobbles multiple tracks at the same UTS — the
      # play_count must reflect unique listening events, not row count.
      track_fixture(%{
        title: "Same UTS Track A",
        album_title: "Same UTS Album",
        artist_name: "Same UTS Artist",
        scrobbled_at_uts: shared_uts
      })

      track_fixture(%{
        title: "Same UTS Track B",
        album_title: "Same UTS Album",
        artist_name: "Same UTS Artist",
        scrobbled_at_uts: shared_uts
      })

      results = ListeningStats.get_top_albums(limit: 10)
      [entry] = Enum.filter(results, fn r -> r.album_title == "Same UTS Album" end)

      assert entry.play_count == 1,
             "expected count(DISTINCT scrobbled_at_uts) semantics — got #{entry.play_count}"
    end

    test "two tracks at the same scrobbled_at_uts count as one play in get_top_artists" do
      shared_uts = System.system_time(:second) - 100

      track_fixture(%{
        title: "Same UTS Track 1",
        artist_name: "Same UTS Solo Artist",
        scrobbled_at_uts: shared_uts
      })

      track_fixture(%{
        title: "Same UTS Track 2",
        artist_name: "Same UTS Solo Artist",
        scrobbled_at_uts: shared_uts
      })

      results = ListeningStats.get_top_artists(limit: 10)
      [entry] = Enum.filter(results, fn r -> r.name == "Same UTS Solo Artist" end)

      assert entry.play_count == 1,
             "expected count(DISTINCT scrobbled_at_uts) semantics — got #{entry.play_count}"
    end
  end

  describe "list_tracks result-map shape" do
    test "always includes :matching_records" do
      track_fixture(%{title: "Shape Test"})

      [result | _] = ListeningStats.list_tracks(%{page: 1, page_size: 5})

      assert Map.has_key?(result, :matching_records),
             "list_tracks result map must include :matching_records"

      assert is_list(result.matching_records)
    end
  end

  describe "get_top_artists/1" do
    test "counts tracks with missing artist_infos records" do
      artist_info =
        artist_info_fixture(%{musicbrainz_data: %{"name" => "Thin Lizzy"}})

      artist_mbid = artist_info.id

      now = System.system_time(:second)

      # Two tracks with a matching artist_infos record
      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: artist_mbid,
        title: "The Boys Are Back in Town",
        scrobbled_at_uts: now - 100
      })

      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: artist_mbid,
        title: "Jailbreak",
        scrobbled_at_uts: now - 200
      })

      # One track with an empty musicbrainz_id (no matching artist_infos)
      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: "",
        title: "Rosalie / Cowgirl's Song",
        scrobbled_at_uts: now - 300
      })

      results = ListeningStats.get_top_artists(limit: 10)

      # All 3 tracks should be counted as a single artist entry
      assert [thin_lizzy] = Enum.filter(results, fn r -> r.name == "Thin Lizzy" end)
      assert thin_lizzy.play_count == 3
      # MAX picks the real musicbrainz_id over the empty string
      assert thin_lizzy.musicbrainz_id == artist_mbid
    end

    test "returns image_hash from artist_infos when available" do
      artist_info =
        artist_info_fixture(%{
          musicbrainz_data: %{"name" => "Test Artist"},
          image_data_hash: "abc123"
        })

      artist_mbid = artist_info.id

      track_fixture(%{
        artist_name: "Test Artist",
        artist_musicbrainz_id: artist_mbid,
        title: "Track 1",
        scrobbled_at_uts: System.system_time(:second) - 100
      })

      [result] = ListeningStats.get_top_artists(limit: 10)

      assert result.image_hash == "abc123"
    end

    test "returns nil image_hash for tracks without artist_infos" do
      track_fixture(%{
        artist_name: "Unknown Artist",
        artist_musicbrainz_id: "",
        title: "Track 1",
        scrobbled_at_uts: System.system_time(:second) - 100
      })

      [result] = ListeningStats.get_top_artists(limit: 10)

      assert result.image_hash == nil
    end
  end

  describe "get_last_listened_track/1" do
    test "returns the most recent scrobbled track for a record" do
      record = RecordsFixtures.record()
      main_artist = Record.main_artist(record)
      now = System.system_time(:second)

      _older =
        track_fixture(%{
          artist_name: main_artist.name,
          album_title: record.title,
          title: "Older Track",
          scrobbled_at_uts: now - 200
        })

      track_fixture(%{
        artist_name: main_artist.name,
        album_title: record.title,
        title: "Newer Track",
        scrobbled_at_uts: now - 100
      })

      result = ListeningStats.get_last_listened_track(record)

      assert result.title == "Newer Track"
      assert result.scrobbled_at_uts == now - 100
    end

    test "returns nil when no scrobbles exist for the record" do
      record = RecordsFixtures.record()

      assert ListeningStats.get_last_listened_track(record) == nil
    end
  end

  describe "play_count/1" do
    test "returns the correct scrobble count for a record" do
      record = RecordsFixtures.record()
      main_artist = Record.main_artist(record)
      now = System.system_time(:second)

      for i <- 1..3 do
        track_fixture(%{
          artist_name: main_artist.name,
          album_title: record.title,
          title: "Track #{i}",
          scrobbled_at_uts: now - i * 100
        })
      end

      assert ListeningStats.play_count(record) == 3
    end

    test "returns 0 when no scrobbles exist for the record" do
      record = RecordsFixtures.record()

      assert ListeningStats.play_count(record) == 0
    end
  end

  describe "daily_scrobble_counts/1" do
    @timezone "Etc/UTC"

    defp uts_for_date(date) do
      {:ok, noon} = DateTime.new(date, ~T[12:00:00], @timezone)
      DateTime.to_unix(noon)
    end

    test "returns exactly 30 days ordered oldest to newest" do
      today = ~D[2026-05-31]
      {:ok, now} = DateTime.new(today, ~T[11:00:00], @timezone)

      track_fixture(%{title: "Today", scrobbled_at_uts: uts_for_date(today)})

      results =
        ListeningStats.daily_scrobble_counts(
          timezone: @timezone,
          days: 30,
          current_time: now
        )

      assert Enum.count_until(results, 31) == 30

      first_date = Date.add(today, -29)
      expected_dates = Enum.to_list(Date.range(first_date, today))

      assert Enum.map(results, & &1.date) == expected_dates

      assert Enum.all?(results, &is_integer(&1.count))
    end

    test "zero-fills days with no scrobbles" do
      today = ~D[2026-05-31]
      {:ok, now} = DateTime.new(today, ~T[11:00:00], @timezone)

      day_1 = Date.add(today, -29)
      day_2 = Date.add(today, -15)

      track_fixture(%{title: "Day 1", scrobbled_at_uts: uts_for_date(day_1)})
      track_fixture(%{title: "Day 15", scrobbled_at_uts: uts_for_date(day_2)})

      results =
        ListeningStats.daily_scrobble_counts(
          timezone: @timezone,
          days: 30,
          current_time: now
        )

      non_zero = Enum.reject(results, &(&1.count == 0))
      assert Enum.count_until(non_zero, 3) == 2

      day_1_entry = Enum.find(results, &(&1.date == day_1))
      assert day_1_entry.count == 1

      day_2_entry = Enum.find(results, &(&1.date == day_2))
      assert day_2_entry.count == 1

      # All other 28 days should be zero
      assert 28 == Enum.count(results, &(&1.count == 0))
    end

    test "excludes tracks before the window" do
      today = ~D[2026-05-31]
      {:ok, now} = DateTime.new(today, ~T[11:00:00], @timezone)

      first_date = Date.add(today, -29)
      before_window = Date.add(first_date, -1)

      track_fixture(%{title: "Before", scrobbled_at_uts: uts_for_date(before_window)})
      track_fixture(%{title: "In window", scrobbled_at_uts: uts_for_date(first_date)})

      results =
        ListeningStats.daily_scrobble_counts(
          timezone: @timezone,
          days: 30,
          current_time: now
        )

      first_day_entry = Enum.find(results, &(&1.date == first_date))
      assert first_day_entry.count == 1

      # Total non-zero should be exactly 1 (the before-window track is excluded)
      assert Enum.count(results, &(&1.count > 0)) == 1
    end

    test "excludes tracks at or after tomorrow's midnight" do
      today = ~D[2026-05-31]
      {:ok, now} = DateTime.new(today, ~T[11:00:00], @timezone)
      tomorrow = Date.add(today, 1)

      # Track exactly at tomorrow midnight (should be excluded)
      {:ok, tomorrow_midnight} = DateTime.new(tomorrow, ~T[00:00:00], @timezone)

      track_fixture(%{
        title: "Tomorrow",
        scrobbled_at_uts: DateTime.to_unix(tomorrow_midnight)
      })

      track_fixture(%{title: "Today", scrobbled_at_uts: uts_for_date(today)})

      results =
        ListeningStats.daily_scrobble_counts(
          timezone: @timezone,
          days: 30,
          current_time: now
        )

      today_entry = Enum.find(results, &(&1.date == today))
      assert today_entry.count == 1

      # No entry for tomorrow in the results (30 days = today + 29 previous)
      refute Enum.any?(results, &(&1.date == tomorrow))

      # Only one track counted
      assert Enum.count(results, &(&1.count > 0)) == 1
    end

    test "counts rows, not distinct timestamps" do
      today = ~D[2026-05-31]
      {:ok, now} = DateTime.new(today, ~T[11:00:00], @timezone)

      # Two tracks at the exact same timestamp on today
      same_uts = uts_for_date(today)
      track_fixture(%{title: "Track A", scrobbled_at_uts: same_uts})
      track_fixture(%{title: "Track B", scrobbled_at_uts: same_uts})

      results =
        ListeningStats.daily_scrobble_counts(
          timezone: @timezone,
          days: 30,
          current_time: now
        )

      today_entry = Enum.find(results, &(&1.date == today))
      assert today_entry.count == 2
    end

    test "groups by local date, respecting timezone boundaries" do
      # Use `Etc/GMT+5` which is 5 hours behind UTC.
      # A track at 03:00 UTC on day X is 22:00 local on day X-1.
      tz = "Etc/GMT+5"
      today = ~D[2026-05-31]
      {:ok, now} = DateTime.new(today, ~T[11:00:00], tz)

      # In GMT+5, today starts at 05:00 UTC (midnight local = 05:00 UTC)
      # A track at 04:00 UTC on 'today' is actually 23:00 local on 'yesterday'
      yesterday_local = Date.add(today, -1)

      # This track is at 04:00 UTC on 'today' date — that's 23:00 GMT+5 on yesterday
      {:ok, utc_4am_today} = DateTime.new(today, ~T[04:00:00], "Etc/UTC")

      track_fixture(%{
        title: "Late night",
        scrobbled_at_uts: DateTime.to_unix(utc_4am_today)
      })

      # This track is at 06:00 UTC on 'today' date — that's 01:00 GMT+5 on today
      {:ok, utc_6am_today} = DateTime.new(today, ~T[06:00:00], "Etc/UTC")

      track_fixture(%{
        title: "Early morning",
        scrobbled_at_uts: DateTime.to_unix(utc_6am_today)
      })

      results =
        ListeningStats.daily_scrobble_counts(
          timezone: tz,
          days: 30,
          current_time: now
        )

      yesterday_entry = Enum.find(results, &(&1.date == yesterday_local))
      assert yesterday_entry.count == 1

      today_entry = Enum.find(results, &(&1.date == today))
      assert today_entry.count == 1
    end
  end

  describe "get_top_artists_by_days/2" do
    test "counts tracks with missing artist_infos records within date range" do
      artist_info =
        artist_info_fixture(%{musicbrainz_data: %{"name" => "Thin Lizzy"}})

      artist_mbid = artist_info.id

      now = DateTime.utc_now()
      now_unix = DateTime.to_unix(now)

      # Two tracks with matching artist_infos
      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: artist_mbid,
        title: "The Boys Are Back in Town",
        scrobbled_at_uts: now_unix - 100
      })

      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: artist_mbid,
        title: "Jailbreak",
        scrobbled_at_uts: now_unix - 200
      })

      # One track with empty musicbrainz_id
      track_fixture(%{
        artist_name: "Thin Lizzy",
        artist_musicbrainz_id: "",
        title: "Rosalie / Cowgirl's Song",
        scrobbled_at_uts: now_unix - 300
      })

      results =
        ListeningStats.get_top_artists_by_days(7,
          limit: 10,
          current_time: now,
          timezone: "Etc/UTC"
        )

      assert [thin_lizzy] = Enum.filter(results, fn r -> r.name == "Thin Lizzy" end)
      assert thin_lizzy.play_count == 3
    end
  end

  defp list_tracks do
    ListeningStats.list_tracks()
    |> Enum.map(fn r -> r.track end)
  end

  defp list_tracks(params) do
    ListeningStats.list_tracks(params)
    |> Enum.map(fn r -> r.track end)
  end
end
