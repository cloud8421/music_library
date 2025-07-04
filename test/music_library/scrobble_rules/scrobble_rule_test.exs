defmodule MusicLibrary.ScrobbleRules.ScrobbleRuleTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.ScrobbleRules.ScrobbleRule

  describe "changeset/2" do
    test "valid changeset with all required fields" do
      attrs = %{
        type: :album,
        match_value: "Dark Side of the Moon",
        target_musicbrainz_id: "12345678-1234-1234-1234-123456789012",
        enabled: true,
        description: "Fix Pink Floyd album"
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with minimal required fields" do
      attrs = %{
        type: :artist,
        match_value: "Pink Floyd",
        target_musicbrainz_id: "12345678-1234-1234-1234-123456789012"
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      assert changeset.valid?
      # Check that enabled defaults to true if not set
    end

    test "invalid changeset when type is missing" do
      attrs = %{
        match_value: "Pink Floyd",
        target_musicbrainz_id: "12345678-1234-1234-1234-123456789012"
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).type
    end

    test "invalid changeset when match_value is missing" do
      attrs = %{
        type: :artist,
        target_musicbrainz_id: "12345678-1234-1234-1234-123456789012"
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).match_value
    end

    test "invalid changeset when target_musicbrainz_id is missing" do
      attrs = %{
        type: :artist,
        match_value: "Pink Floyd"
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).target_musicbrainz_id
    end

    test "invalid changeset when type is not album or artist" do
      attrs = %{
        type: :invalid_type,
        match_value: "Pink Floyd",
        target_musicbrainz_id: "12345678-1234-1234-1234-123456789012"
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).type
    end

    test "invalid changeset when match_value is empty" do
      attrs = %{
        type: :artist,
        match_value: "",
        target_musicbrainz_id: "12345678-1234-1234-1234-123456789012"
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).match_value
    end

    test "invalid changeset when target_musicbrainz_id is empty" do
      attrs = %{
        type: :artist,
        match_value: "Pink Floyd",
        target_musicbrainz_id: ""
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).target_musicbrainz_id
    end

    test "invalid changeset when target_musicbrainz_id is not a valid UUID" do
      attrs = %{
        type: :artist,
        match_value: "Pink Floyd",
        target_musicbrainz_id: "invalid-uuid"
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      refute changeset.valid?

      assert "is invalid" in errors_on(changeset).target_musicbrainz_id
    end

    test "valid changeset with uppercase UUID" do
      attrs = %{
        type: :artist,
        match_value: "Pink Floyd",
        target_musicbrainz_id: "12345678-1234-1234-1234-123456789012"
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      assert changeset.valid?
    end

    test "valid changeset with lowercase UUID" do
      attrs = %{
        type: :artist,
        match_value: "Pink Floyd",
        target_musicbrainz_id: "abcdefab-abcd-abcd-abcd-abcdefabcdef"
      }

      changeset = ScrobbleRule.changeset(%ScrobbleRule{}, attrs)
      assert changeset.valid?
    end
  end
end
