defmodule MusicLibrary.SqlHelpersTest do
  use MusicLibrary.DataCase

  import Ecto.Query
  import MusicLibrary.SqlHelpers

  alias LastFm.Track
  alias MusicLibrary.ScrobbleRules.ScrobbleRule

  describe "json_extract/2 macro" do
    test "generates correct SQL fragment" do
      query = from(t in Track, where: json_extract(t.album, "$.title") == "Test Album")

      {sql, _params} = Repo.to_sql(:all, query)

      assert sql ==
               "SELECT s0.\"scrobbled_at_uts\", s0.\"musicbrainz_id\", s0.\"title\", s0.\"cover_url\", s0.\"scrobbled_at_label\", s0.\"artist\", s0.\"album\", s0.\"last_fm_data\" FROM \"scrobbled_tracks\" AS s0 WHERE (json_extract(s0.\"album\", '$.title') = 'Test Album')"
    end
  end

  describe "json_set/3 macro" do
    test "generates correct SQL fragment" do
      query =
        from(t in Track,
          update: [set: [album: json_set(t.album, "$.musicbrainz_id", "test-id")]]
        )

      {sql, _params} = Repo.to_sql(:update_all, query)

      assert sql ==
               "UPDATE \"scrobbled_tracks\" AS s0 SET \"album\" = json_set(s0.\"album\", '$.musicbrainz_id', 'test-id')"
    end
  end

  describe "case_when/2" do
    test "builds CASE statement for single rule" do
      rule = %ScrobbleRule{
        match_value: "Dark Side of the Moon",
        target_musicbrainz_id: "12345678-1234-1234-1234-123456789012"
      }

      field_spec = %{
        field: "album",
        json_path: "$.title",
        update_path: "$.musicbrainz_id"
      }

      {case_sql, case_params, match_values} = case_when([rule], field_spec)

      assert case_sql =~
               "CASE WHEN json_extract(album, '$.title') = ? THEN json_set(album, '$.musicbrainz_id', ?) ELSE album END"

      assert case_params == [
               "Dark Side of the Moon",
               "12345678-1234-1234-1234-123456789012"
             ]

      assert match_values == ["Dark Side of the Moon"]
    end

    test "builds CASE statement for multiple rules" do
      rule1 = %ScrobbleRule{
        match_value: "Album 1",
        target_musicbrainz_id: "mbid-1"
      }

      rule2 = %ScrobbleRule{
        match_value: "Album 2",
        target_musicbrainz_id: "mbid-2"
      }

      field_spec = %{
        field: "album",
        json_path: "$.title",
        update_path: "$.musicbrainz_id"
      }

      {case_sql, case_params, match_values} = case_when([rule1, rule2], field_spec)

      assert case_sql =~ "WHEN json_extract(album, '$.title') = ?"
      assert String.match?(case_sql, ~r/WHEN.*WHEN/)
      assert case_sql =~ "ELSE album END"

      assert case_params == ["Album 1", "mbid-1", "Album 2", "mbid-2"]
      assert match_values == ["Album 1", "Album 2"]
    end

    test "works with artist field spec" do
      rule = %ScrobbleRule{
        match_value: "Pink Floyd",
        target_musicbrainz_id: "artist-mbid"
      }

      field_spec = %{
        field: "artist",
        json_path: "$.name",
        update_path: "$.musicbrainz_id"
      }

      {case_sql, case_params, match_values} = case_when([rule], field_spec)

      assert case_sql =~
               "CASE WHEN json_extract(artist, '$.name') = ? THEN json_set(artist, '$.musicbrainz_id', ?) ELSE artist END"

      assert case_params == ["Pink Floyd", "artist-mbid"]
      assert match_values == ["Pink Floyd"]
    end
  end
end
