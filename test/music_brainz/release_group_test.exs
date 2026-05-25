defmodule MusicBrainz.ReleaseGroupTest do
  use ExUnit.Case, async: true

  alias MusicBrainz.ReleaseGroup

  describe "parse_artist_credits/1" do
    test "extracts artist credits with joinphrases" do
      musicbrainz_data = %{
        "artist-credit" => [
          %{
            "joinphrase" => " & ",
            "artist" => %{
              "id" => "mbid-1",
              "name" => "Steven Wilson",
              "sort-name" => "Wilson, Steven",
              "disambiguation" => "English musician"
            }
          },
          %{
            "joinphrase" => "",
            "artist" => %{
              "id" => "mbid-2",
              "name" => "Mikael Åkerfeldt",
              "sort-name" => "Åkerfeldt, Mikael",
              "disambiguation" => "Swedish musician"
            }
          }
        ]
      }

      assert ReleaseGroup.parse_artist_credits(musicbrainz_data) == [
               %{
                 name: "Steven Wilson",
                 musicbrainz_id: "mbid-1",
                 sort_name: "Wilson, Steven",
                 disambiguation: "English musician",
                 joinphrase: " & "
               },
               %{
                 name: "Mikael Åkerfeldt",
                 musicbrainz_id: "mbid-2",
                 sort_name: "Åkerfeldt, Mikael",
                 disambiguation: "Swedish musician",
                 joinphrase: ""
               }
             ]
    end

    test "returns empty list when artist-credit key is empty list" do
      assert ReleaseGroup.parse_artist_credits(%{"artist-credit" => []}) == []
    end

    test "returns empty list when artist-credit has no artists" do
      assert ReleaseGroup.parse_artist_credits(%{"artist-credit" => []}) == []
    end
  end

  describe "included_release_groups/1" do
    test "filters related release groups with correct target-type and direction" do
      release_group = %{
        "relations" => [
          %{
            "target-type" => "release_group",
            "type" => "included in",
            "direction" => "backward",
            "release_group" => %{
              "id" => "rg-included-1",
              "primary-type" => "EP",
              "title" => "Bonus Disc",
              "artist-credit" => [
                %{"artist" => %{"name" => "Test Artist"}, "joinphrase" => ""}
              ],
              "first-release-date" => "2020-01-01"
            }
          },
          %{
            "target-type" => "url",
            "type" => "other databases",
            "direction" => "forward",
            "release_group" => nil
          },
          %{
            "target-type" => "release_group",
            "type" => "included in",
            "direction" => "forward",
            "release_group" => %{
              "id" => "rg-forward",
              "primary-type" => "Album",
              "title" => "Forward RG",
              "artist-credit" => [],
              "first-release-date" => "2019-01-01"
            }
          }
        ]
      }

      result = ReleaseGroup.included_release_groups(release_group)
      assert Enum.count_until(result, 2) == 1
      assert hd(result).id == "rg-included-1"
      assert hd(result).type == :ep
    end

    test "returns empty list when no relations key" do
      assert ReleaseGroup.included_release_groups(%{}) == []
    end

    test "returns empty list when no matching relations" do
      release_group = %{
        "relations" => [
          %{
            "target-type" => "url",
            "type" => "wikipedia",
            "direction" => "forward"
          }
        ]
      }

      assert ReleaseGroup.included_release_groups(release_group) == []
    end
  end

  describe "release_ids/1" do
    test "extracts IDs from releases" do
      release_group = %{
        "releases" => [
          %{"id" => "rel-1"},
          %{"id" => "rel-2"},
          %{"id" => "rel-3"}
        ]
      }

      assert ReleaseGroup.release_ids(release_group) == ["rel-1", "rel-2", "rel-3"]
    end

    test "returns empty list when no releases" do
      assert ReleaseGroup.release_ids(%{}) == []
      assert ReleaseGroup.release_ids(%{"releases" => []}) == []
    end
  end

  describe "included_release_group_ids/1" do
    test "extracts IDs from included release groups" do
      release_group = %{
        "relations" => [
          %{
            "target-type" => "release_group",
            "type" => "included in",
            "direction" => "backward",
            "release_group" => %{
              "id" => "rg-sub-1",
              "primary-type" => "EP",
              "title" => "Bonus",
              "artist-credit" => [],
              "first-release-date" => "2020-01-01"
            }
          }
        ]
      }

      assert ReleaseGroup.included_release_group_ids(release_group) == ["rg-sub-1"]
    end
  end

  describe "parse_record_type/2" do
    test "Album without special secondary types is :album" do
      assert ReleaseGroup.parse_record_type("Album", ["Soundtrack"]) == :album
    end

    test "Album with Live secondary type is :live" do
      assert ReleaseGroup.parse_record_type("Album", ["Live"]) == :live
    end

    test "Album with Compilation secondary type is :compilation" do
      assert ReleaseGroup.parse_record_type("Album", ["Compilation"]) == :compilation
    end

    test "Live overrides Compilation when both are in secondary types" do
      assert ReleaseGroup.parse_record_type("Album", ["Compilation", "Live"]) == :live
    end

    test "Album with nil secondary types defaults to :album" do
      assert ReleaseGroup.parse_record_type("Album", nil) == :album
    end

    test "EP maps to :ep" do
      assert ReleaseGroup.parse_record_type("EP", ["Live"]) == :ep
    end

    test "Single maps to :single" do
      assert ReleaseGroup.parse_record_type("Single", nil) == :single
    end

    test "Unknown primary type maps to :other" do
      assert ReleaseGroup.parse_record_type("Broadcast", nil) == :other
      assert ReleaseGroup.parse_record_type(nil, nil) == :other
    end
  end

  describe "parse_type/1" do
    test "maps known types to atoms" do
      assert ReleaseGroup.parse_type("Album") == :album
      assert ReleaseGroup.parse_type("EP") == :ep
      assert ReleaseGroup.parse_type("Live") == :live
      assert ReleaseGroup.parse_type("Compilation") == :compilation
      assert ReleaseGroup.parse_type("Single") == :single
    end

    test "maps unknown types to :other" do
      assert ReleaseGroup.parse_type("Broadcast") == :other
      assert ReleaseGroup.parse_type(nil) == :other
      assert ReleaseGroup.parse_type("") == :other
    end
  end

  describe "url/1" do
    test "generates MusicBrainz URL" do
      assert ReleaseGroup.url("mbid-123") == "https://musicbrainz.org/release-group/mbid-123"
    end
  end
end
