defmodule MusicLibrary.Collection.EnrichmentTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Collection.Enrichment
  alias MusicLibrary.Fixtures.Records
  alias MusicLibrary.ScrobbledTracksFixtures

  describe "enrich_scrobbles/1" do
    test "adds scrobble_count and last_listened_at when scrobbles exist" do
      record = Records.record()
      release_id = hd(record.release_ids)

      # Insert a scrobbled track referencing this release_id
      _track =
        ScrobbledTracksFixtures.track_fixture(%{
          album_musicbrainz_id: release_id,
          album_title: record.title,
          scrobbled_at_uts: 1_700_000_000
        })

      _track2 =
        ScrobbledTracksFixtures.track_fixture(%{
          album_musicbrainz_id: release_id,
          album_title: record.title,
          scrobbled_at_uts: 1_700_000_100
        })

      [enriched] = Enrichment.enrich_scrobbles([record])

      assert enriched.scrobble_count == 2
      assert enriched.last_listened_at != nil
      assert String.contains?(enriched.last_listened_at, "T")
    end

    test "returns zero and nil when no scrobbles match" do
      record = Records.record()

      [enriched] = Enrichment.enrich_scrobbles([record])

      assert enriched.scrobble_count == 0
      assert enriched.last_listened_at == nil
    end

    test "matches scrobbles by title and main artist when album musicbrainz_id is missing" do
      record =
        Records.record_with_artist("Fallback Artist", %{
          title: "Fallback Album"
        })

      uts = 1_700_000_200

      _track =
        ScrobbledTracksFixtures.track_fixture(%{
          album_musicbrainz_id: "",
          album_title: "Fallback Album",
          artist_name: "Fallback Artist",
          scrobbled_at_uts: uts
        })

      _non_matching_track =
        ScrobbledTracksFixtures.track_fixture(%{
          album_musicbrainz_id: "",
          album_title: "Fallback Album",
          artist_name: "Different Artist",
          scrobbled_at_uts: 1_700_000_300
        })

      [enriched] = Enrichment.enrich_scrobbles([record])

      expected_iso = uts |> DateTime.from_unix!() |> DateTime.to_iso8601()

      assert enriched.scrobble_count == 1
      assert enriched.last_listened_at == expected_iso
    end

    test "returns zero and nil when release_ids is empty" do
      record = Records.record(%{release_ids: []})

      [enriched] = Enrichment.enrich_scrobbles([record])

      assert enriched.scrobble_count == 0
      assert enriched.last_listened_at == nil
    end

    test "returns zero and nil when release_ids is nil" do
      record = Records.record(%{release_ids: nil})

      [enriched] = Enrichment.enrich_scrobbles([record])

      assert enriched.scrobble_count == 0
      assert enriched.last_listened_at == nil
    end

    test "sums scrobbles across multiple release_ids for the same record" do
      release_ids = ["release-a", "release-b"]

      record = Records.record(%{release_ids: release_ids, musicbrainz_data: nil})

      _track =
        ScrobbledTracksFixtures.track_fixture(%{
          album_musicbrainz_id: "release-a",
          album_title: "Album A",
          scrobbled_at_uts: 1_700_000_000
        })

      _track2 =
        ScrobbledTracksFixtures.track_fixture(%{
          album_musicbrainz_id: "release-b",
          album_title: "Album B",
          scrobbled_at_uts: 1_700_000_100
        })

      [enriched] = Enrichment.enrich_scrobbles([record])

      assert enriched.scrobble_count == 2
    end

    test "takes the max last_listened_at across release_ids" do
      release_ids = ["release-a", "release-b"]

      record = Records.record(%{release_ids: release_ids, musicbrainz_data: nil})

      earlier = 1_700_000_000
      later = 1_700_000_500

      _track =
        ScrobbledTracksFixtures.track_fixture(%{
          album_musicbrainz_id: "release-a",
          album_title: "Album A",
          scrobbled_at_uts: earlier
        })

      _track2 =
        ScrobbledTracksFixtures.track_fixture(%{
          album_musicbrainz_id: "release-b",
          album_title: "Album B",
          scrobbled_at_uts: later
        })

      [enriched] = Enrichment.enrich_scrobbles([record])

      expected_iso = later |> DateTime.from_unix!() |> DateTime.to_iso8601()
      assert enriched.last_listened_at == expected_iso
    end

    test "two records sharing a release group both get scrobble counts" do
      release_ids = ["shared-release"]
      record1 = Records.record(%{release_ids: release_ids, musicbrainz_data: nil})
      record2 = Records.record(%{release_ids: release_ids, musicbrainz_data: nil})

      _track =
        ScrobbledTracksFixtures.track_fixture(%{
          album_musicbrainz_id: "shared-release",
          album_title: "Shared",
          scrobbled_at_uts: 1_700_000_000
        })

      [enriched1, enriched2] = Enrichment.enrich_scrobbles([record1, record2])

      assert enriched1.scrobble_count == 1
      assert enriched2.scrobble_count == 1
    end
  end

  describe "enrich_artist_country/1" do
    test "adds artist_country when artist_info exists with country data" do
      record = Records.record()

      main_artist = hd(record.artists)
      artist_mbid = main_artist.musicbrainz_id

      # Create artist_info with area data (UK)
      Records.artist_info(artist_mbid, %{
        musicbrainz_data: %{
          "name" => "Steven Wilson",
          "area" => %{
            "name" => "United Kingdom",
            "iso-3166-1-codes" => ["GB"]
          }
        }
      })

      [enriched] = Enrichment.enrich_artist_country([record])

      assert enriched.artist_country == %{name: "United Kingdom", code: "GB"}
    end

    test "returns nil when artist_info row does not exist" do
      record = Records.record()

      [enriched] = Enrichment.enrich_artist_country([record])

      assert enriched.artist_country == nil
    end

    test "returns nil when artists list is empty" do
      record = Records.record(%{artists: []})

      [enriched] = Enrichment.enrich_artist_country([record])

      assert enriched.artist_country == nil
    end

    test "reuses lookup for multiple records with same main artist" do
      artist_name = "Pink Floyd"
      record1 = Records.record_with_artist(artist_name)
      record2 = Records.record_with_artist(artist_name)

      artist_mbid = hd(record1.artists).musicbrainz_id

      # Only one artist_info created, shared by both records
      Records.artist_info(artist_mbid, %{
        musicbrainz_data: %{
          "name" => "Pink Floyd",
          "area" => %{
            "name" => "United Kingdom",
            "iso-3166-1-codes" => ["GB"]
          }
        }
      })

      [enriched1, enriched2] = Enrichment.enrich_artist_country([record1, record2])

      assert enriched1.artist_country == %{name: "United Kingdom", code: "GB"}
      assert enriched2.artist_country == %{name: "United Kingdom", code: "GB"}
    end

    test "returns nil for record whose artist lacks an artist_infos row" do
      artist_name = "Unknown Artist"
      record = Records.record_with_artist(artist_name)

      [enriched] = Enrichment.enrich_artist_country([record])

      assert enriched.artist_country == nil
    end
  end

  describe "enrich_selected_release/1" do
    test "adds selected_release with all six fields when matching release exists" do
      record = Records.record()

      [enriched] = Enrichment.enrich_selected_release([record])

      assert enriched.selected_release != nil
      assert is_map(enriched.selected_release)

      assert enriched.selected_release == %{
               format: "multi",
               date: "2004-05-03",
               country: "GB",
               catalog_number: "",
               packaging: "Jewel Case",
               disambiguation: ""
             }
    end

    test "returns nil when selected_release_id is nil" do
      record = Records.record(%{selected_release_id: nil})

      [enriched] = Enrichment.enrich_selected_release([record])

      assert enriched.selected_release == nil
    end

    test "returns nil when selected_release_id is empty string" do
      record = Records.record(%{selected_release_id: ""})

      [enriched] = Enrichment.enrich_selected_release([record])

      assert enriched.selected_release == nil
    end

    test "returns nil when selected_release_id does not match any release" do
      record = Records.record(%{selected_release_id: "nonexistent-release-id"})

      [enriched] = Enrichment.enrich_selected_release([record])

      assert enriched.selected_release == nil
    end

    test "multiple records enriched independently" do
      record1 = Records.record()
      record2 = Records.record(%{selected_release_id: nil})

      [enriched1, enriched2] = Enrichment.enrich_selected_release([record1, record2])

      assert enriched1.selected_release != nil
      assert enriched2.selected_release == nil
    end
  end

  describe "enrich/1" do
    test "composes all three enrichments, adding all four fields" do
      record = Records.record()

      main_artist = hd(record.artists)
      artist_mbid = main_artist.musicbrainz_id

      Records.artist_info(artist_mbid, %{
        musicbrainz_data: %{
          "name" => "Steven Wilson",
          "area" => %{
            "name" => "United Kingdom",
            "iso-3166-1-codes" => ["GB"]
          }
        }
      })

      [enriched] = Enrichment.enrich([record])

      # All four new fields are present
      assert Map.has_key?(enriched, :scrobble_count)
      assert Map.has_key?(enriched, :last_listened_at)
      assert Map.has_key?(enriched, :artist_country)
      assert Map.has_key?(enriched, :selected_release)

      # Original fields are preserved
      assert enriched.id == record.id
      assert enriched.title == record.title
      assert enriched.musicbrainz_id == record.musicbrainz_id
      assert enriched.artists == record.artists
    end

    test "handles empty list gracefully" do
      assert Enrichment.enrich([]) == []
    end
  end
end
