defmodule MusicLibrary.ScrobbleRulesTest do
  use MusicLibrary.DataCase

  alias LastFm.Track
  alias MusicLibrary.ScrobbleRules
  alias MusicLibrary.ScrobbleRules.ScrobbleRule

  describe "scrobble_rules" do
    @valid_album_attrs %{
      type: "album",
      match_value: "Dark Side of the Moon",
      target_musicbrainz_id: "12345678-1234-1234-1234-123456789012",
      enabled: true,
      description: "Fix Pink Floyd album"
    }

    @valid_artist_attrs %{
      type: "artist",
      match_value: "Pink Floyd",
      target_musicbrainz_id: "87654321-4321-4321-4321-210987654321",
      enabled: true,
      description: "Fix Pink Floyd artist"
    }

    @invalid_attrs %{type: nil, match_value: nil, target_musicbrainz_id: nil}

    def scrobble_rule_fixture(attrs \\ %{}) do
      {:ok, scrobble_rule} =
        attrs
        |> Enum.into(@valid_album_attrs)
        |> ScrobbleRules.create_scrobble_rule()

      scrobble_rule
    end

    def scrobbled_track_fixture(attrs \\ %{}) do
      default_attrs = %{
        scrobbled_at_uts: System.system_time(:second),
        musicbrainz_id: "track-mbid-12345",
        title: "Breathe",
        cover_url: "http://example.com/cover.jpg",
        scrobbled_at_label: "01 Jan 2023, 12:00",
        artist: %{
          musicbrainz_id: "",
          name: "Pink Floyd"
        },
        album: %{
          musicbrainz_id: "",
          title: "Dark Side of the Moon"
        },
        last_fm_data: %{}
      }

      attrs = Enum.into(attrs, default_attrs)

      %Track{}
      |> Track.changeset(attrs)
      |> Repo.insert!()
    end

    test "list_scrobble_rules/0 returns all scrobble_rules" do
      scrobble_rule = scrobble_rule_fixture()
      assert ScrobbleRules.list_scrobble_rules() == [scrobble_rule]
    end

    test "list_scrobble_rules/1 filters by type" do
      album_rule = scrobble_rule_fixture(@valid_album_attrs)
      _artist_rule = scrobble_rule_fixture(@valid_artist_attrs)

      assert ScrobbleRules.list_scrobble_rules(type: "album") == [album_rule]
    end

    test "list_scrobble_rules/1 filters by enabled status" do
      enabled_rule = scrobble_rule_fixture(%{enabled: true})
      _disabled_rule = scrobble_rule_fixture(%{enabled: false, match_value: "Different Album"})

      assert ScrobbleRules.list_scrobble_rules(enabled: true) == [enabled_rule]
    end

    test "get_scrobble_rule!/1 returns the scrobble_rule with given id" do
      scrobble_rule = scrobble_rule_fixture()
      assert ScrobbleRules.get_scrobble_rule!(scrobble_rule.id) == scrobble_rule
    end

    test "create_scrobble_rule/1 with valid data creates a scrobble_rule" do
      valid_attrs = @valid_album_attrs

      assert {:ok, %ScrobbleRule{} = scrobble_rule} =
               ScrobbleRules.create_scrobble_rule(valid_attrs)

      assert scrobble_rule.type == :album
      assert scrobble_rule.match_value == "Dark Side of the Moon"
      assert scrobble_rule.target_musicbrainz_id == "12345678-1234-1234-1234-123456789012"
      assert scrobble_rule.enabled == true
      assert scrobble_rule.description == "Fix Pink Floyd album"
    end

    test "create_scrobble_rule/1 doesn't allow duplicates for the same type" do
      valid_attrs = Map.put(@valid_album_attrs, :type, :album)

      assert {:ok, %ScrobbleRule{} = scrobble_rule} =
               ScrobbleRules.create_scrobble_rule(valid_attrs)

      assert scrobble_rule.type == :album

      assert {:error, _changeset} = ScrobbleRules.create_scrobble_rule(valid_attrs)
    end

    test "create_scrobble_rule/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = ScrobbleRules.create_scrobble_rule(@invalid_attrs)
    end

    test "update_scrobble_rule/2 with valid data updates the scrobble_rule" do
      scrobble_rule = scrobble_rule_fixture()
      update_attrs = %{enabled: false, description: "Updated description"}

      assert {:ok, %ScrobbleRule{} = scrobble_rule} =
               ScrobbleRules.update_scrobble_rule(scrobble_rule, update_attrs)

      assert scrobble_rule.enabled == false
      assert scrobble_rule.description == "Updated description"
    end

    test "update_scrobble_rule/2 with invalid data returns error changeset" do
      scrobble_rule = scrobble_rule_fixture()

      assert {:error, %Ecto.Changeset{}} =
               ScrobbleRules.update_scrobble_rule(scrobble_rule, @invalid_attrs)

      assert scrobble_rule == ScrobbleRules.get_scrobble_rule!(scrobble_rule.id)
    end

    test "delete_scrobble_rule/1 deletes the scrobble_rule" do
      scrobble_rule = scrobble_rule_fixture()
      assert {:ok, %ScrobbleRule{}} = ScrobbleRules.delete_scrobble_rule(scrobble_rule)

      assert_raise Ecto.NoResultsError, fn ->
        ScrobbleRules.get_scrobble_rule!(scrobble_rule.id)
      end
    end

    test "change_scrobble_rule/1 returns a scrobble_rule changeset" do
      scrobble_rule = scrobble_rule_fixture()
      assert %Ecto.Changeset{} = ScrobbleRules.change_scrobble_rule(scrobble_rule)
    end

    test "list_enabled_rules/0 returns only enabled rules" do
      enabled_rule = scrobble_rule_fixture(%{enabled: true})
      _disabled_rule = scrobble_rule_fixture(%{enabled: false, match_value: "Different Album"})

      assert ScrobbleRules.list_enabled_rules() == [enabled_rule]
    end
  end

  describe "rule application" do
    test "apply_album_rule/1 updates matching tracks" do
      rule = scrobble_rule_fixture(@valid_album_attrs)

      # Create matching track
      track1 =
        scrobbled_track_fixture(%{
          album: %{musicbrainz_id: "", title: "Dark Side of the Moon"}
        })

      # Create non-matching track
      _track2 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 1,
          album: %{musicbrainz_id: "", title: "Wish You Were Here"}
        })

      assert {:ok, 1} = ScrobbleRules.apply_album_rule(rule)

      # Verify the matching track was updated
      updated_track = Repo.get_by(Track, scrobbled_at_uts: track1.scrobbled_at_uts)
      assert updated_track.album.musicbrainz_id == rule.target_musicbrainz_id
    end

    test "apply_artist_rule/1 updates matching tracks" do
      rule = scrobble_rule_fixture(@valid_artist_attrs)

      # Create matching track
      track1 =
        scrobbled_track_fixture(%{
          artist: %{musicbrainz_id: "", name: "Pink Floyd"}
        })

      # Create non-matching track
      _track2 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 1,
          artist: %{musicbrainz_id: "", name: "Led Zeppelin"}
        })

      assert {:ok, 1} = ScrobbleRules.apply_artist_rule(rule)

      # Verify the matching track was updated
      updated_track = Repo.get_by(Track, scrobbled_at_uts: track1.scrobbled_at_uts)
      assert updated_track.artist.musicbrainz_id == rule.target_musicbrainz_id
    end

    test "apply_rule/1 delegates to correct function based on type" do
      album_rule = scrobble_rule_fixture(@valid_album_attrs)
      artist_rule = scrobble_rule_fixture(@valid_artist_attrs)

      # Create test tracks that only match their respective rules
      _album_track =
        scrobbled_track_fixture(%{
          album: %{musicbrainz_id: "", title: "Dark Side of the Moon"},
          artist: %{musicbrainz_id: "", name: "Different Artist"}
        })

      _artist_track =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 1,
          artist: %{musicbrainz_id: "", name: "Pink Floyd"},
          album: %{musicbrainz_id: "", title: "Different Album"}
        })

      assert {:ok, 1} = ScrobbleRules.apply_rule(album_rule)
      assert {:ok, 1} = ScrobbleRules.apply_rule(artist_rule)
    end

    test "apply_all_rules/0 applies all enabled rules" do
      _album_rule = scrobble_rule_fixture(@valid_album_attrs)
      _artist_rule = scrobble_rule_fixture(@valid_artist_attrs)
      _disabled_rule = scrobble_rule_fixture(%{enabled: false, match_value: "Disabled Album"})

      # Create test tracks that only match their respective rules
      _album_track =
        scrobbled_track_fixture(%{
          album: %{musicbrainz_id: "", title: "Dark Side of the Moon"},
          artist: %{musicbrainz_id: "", name: "Different Artist"}
        })

      _artist_track =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 1,
          artist: %{musicbrainz_id: "", name: "Pink Floyd"},
          album: %{musicbrainz_id: "", title: "Different Album"}
        })

      assert results = ScrobbleRules.apply_all_rules()
      assert length(results) == 2

      # Verify all results are successful
      Enum.each(results, fn result ->
        assert {:ok, {_type, _match_value, _count}} = result
      end)
    end

    test "count_album_matches/1 returns correct count" do
      rule = scrobble_rule_fixture(@valid_album_attrs)

      # Create matching tracks
      _track1 =
        scrobbled_track_fixture(%{
          album: %{musicbrainz_id: "", title: "Dark Side of the Moon"}
        })

      _track2 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 1,
          album: %{musicbrainz_id: "", title: "Dark Side of the Moon"}
        })

      # Create non-matching track
      _track3 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 2,
          album: %{musicbrainz_id: "", title: "Wish You Were Here"}
        })

      assert ScrobbleRules.count_album_matches(rule) == 2
    end

    test "count_artist_matches/1 returns correct count" do
      rule = scrobble_rule_fixture(@valid_artist_attrs)

      # Create matching tracks
      _track1 =
        scrobbled_track_fixture(%{
          artist: %{musicbrainz_id: "", name: "Pink Floyd"}
        })

      _track2 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 1,
          artist: %{musicbrainz_id: "", name: "Pink Floyd"}
        })

      # Create non-matching track
      _track3 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 2,
          artist: %{musicbrainz_id: "", name: "Led Zeppelin"}
        })

      assert ScrobbleRules.count_artist_matches(rule) == 2
    end

    test "apply_all_album_rules/1 applies multiple album rules in one query" do
      # Create two album rules
      rule1 = scrobble_rule_fixture(@valid_album_attrs)

      rule2 =
        scrobble_rule_fixture(%{
          match_value: "Wish You Were Here",
          target_musicbrainz_id: "abcdef12-3456-7890-abcd-ef1234567890"
        })

      # Create tracks matching each rule
      track1 =
        scrobbled_track_fixture(%{
          album: %{musicbrainz_id: "", title: "Dark Side of the Moon"}
        })

      track2 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 1,
          album: %{musicbrainz_id: "", title: "Wish You Were Here"}
        })

      # Create a non-matching track
      _track3 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 2,
          album: %{musicbrainz_id: "", title: "The Wall"}
        })

      # Apply both rules at once
      assert {:ok, 2} = ScrobbleRules.apply_all_album_rules([rule1, rule2])

      # Verify both tracks were updated by fetching them again
      updated_track1 = Repo.get(Track, track1.scrobbled_at_uts)
      assert updated_track1.album.musicbrainz_id == rule1.target_musicbrainz_id

      updated_track2 = Repo.get(Track, track2.scrobbled_at_uts)
      assert updated_track2.album.musicbrainz_id == rule2.target_musicbrainz_id
    end

    test "apply_all_artist_rules/1 applies multiple artist rules in one query" do
      # Create two artist rules
      rule1 = scrobble_rule_fixture(@valid_artist_attrs)

      rule2 =
        scrobble_rule_fixture(%{
          type: :artist,
          match_value: "Led Zeppelin",
          target_musicbrainz_id: "fedcba98-7654-3210-fedc-ba9876543210"
        })

      # Create tracks matching each rule
      track1 =
        scrobbled_track_fixture(%{
          artist: %{musicbrainz_id: "", name: "Pink Floyd"}
        })

      track2 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 1,
          artist: %{musicbrainz_id: "", name: "Led Zeppelin"}
        })

      # Create a non-matching track
      _track3 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 2,
          artist: %{musicbrainz_id: "", name: "The Beatles"}
        })

      # Apply both rules at once
      assert {:ok, 2} = ScrobbleRules.apply_all_artist_rules([rule1, rule2])

      # Verify both tracks were updated by fetching them again
      updated_track1 = Repo.get(Track, track1.scrobbled_at_uts)
      assert updated_track1.artist.musicbrainz_id == rule1.target_musicbrainz_id

      updated_track2 = Repo.get(Track, track2.scrobbled_at_uts)
      assert updated_track2.artist.musicbrainz_id == rule2.target_musicbrainz_id
    end

    test "apply_all_album_rules/1 with empty list returns 0" do
      assert {:ok, 0} = ScrobbleRules.apply_all_album_rules([])
    end

    test "apply_all_artist_rules/1 with empty list returns 0" do
      assert {:ok, 0} = ScrobbleRules.apply_all_artist_rules([])
    end

    test "apply_all_rules/0 batches rules by type" do
      # Create multiple rules of each type
      _album_rule1 = scrobble_rule_fixture(@valid_album_attrs)

      _album_rule2 =
        scrobble_rule_fixture(%{
          match_value: "Wish You Were Here",
          target_musicbrainz_id: "abcdef12-3456-7890-abcd-ef1234567890"
        })

      _artist_rule1 = scrobble_rule_fixture(@valid_artist_attrs)

      _artist_rule2 =
        scrobble_rule_fixture(%{
          type: :artist,
          match_value: "Led Zeppelin",
          target_musicbrainz_id: "fedcba98-7654-3210-fedc-ba9876543210"
        })

      # Create tracks matching the rules
      _track1 =
        scrobbled_track_fixture(%{
          album: %{musicbrainz_id: "", title: "Dark Side of the Moon"},
          artist: %{musicbrainz_id: "", name: "Pink Floyd"}
        })

      _track2 =
        scrobbled_track_fixture(%{
          scrobbled_at_uts: System.system_time(:second) + 1,
          album: %{musicbrainz_id: "", title: "Wish You Were Here"},
          artist: %{musicbrainz_id: "", name: "Led Zeppelin"}
        })

      # Apply all rules
      results = ScrobbleRules.apply_all_rules()

      # Should have 4 results (one for each rule)
      assert length(results) == 4

      # All results should be successful
      Enum.each(results, fn result ->
        assert {:ok, {_type, _match_value, count}} = result
        # Count should be > 0 since we have matching tracks
        assert count > 0
      end)
    end
  end
end
