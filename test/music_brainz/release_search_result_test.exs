defmodule MusicBrainz.ReleaseSearchResultTest do
  use ExUnit.Case, async: true

  doctest MusicBrainz.ReleaseSearchResult

  alias MusicBrainz.ReleaseSearchResult

  describe "from_api_response/1" do
    test "handles missing release-group" do
      r = %{
        "id" => "rel-1",
        "title" => "No Release Group",
        "artist-credit" => [
          %{"artist" => %{"name" => "Artist Name"}}
        ],
        "date" => "2020-01-01",
        "barcode" => "1234",
        "media" => [%{"format" => "CD", "track-count" => 10, "disc-count" => 1}]
      }

      result = ReleaseSearchResult.from_api_response(r)
      assert result.id == "rel-1"
      assert result.release_group == nil
      assert result.artists == "Artist Name"
    end

    test "handles missing artist-credit" do
      r = %{
        "id" => "rel-2",
        "title" => "No Artists",
        "release-group" => %{
          "id" => "rg-1",
          "primary-type" => "Album",
          "title" => "The Album"
        },
        "date" => nil,
        "barcode" => nil,
        "media" => []
      }

      result = ReleaseSearchResult.from_api_response(r)
      assert result.artists == ""
      assert result.release_group.type == :album
    end
  end

  describe "format/1" do
    test "returns :unknown for nil media format" do
      result = %ReleaseSearchResult{
        id: "1",
        title: "T",
        release_group: nil,
        artists: "A",
        date: "2000",
        barcode: "0",
        media: [%{format: nil, disc_count: 0, track_count: 5}]
      }

      assert ReleaseSearchResult.format(result) == :unknown
    end

    test "returns :unknown for completely unknown format string" do
      result = %ReleaseSearchResult{
        id: "1",
        title: "T",
        release_group: nil,
        artists: "A",
        date: "2000",
        barcode: "0",
        media: [%{format: "Wax Cylinder", disc_count: 0, track_count: 4}]
      }

      assert ReleaseSearchResult.format(result) == :unknown
    end

    test "returns :multi for empty media list" do
      result = %ReleaseSearchResult{
        id: "1",
        title: "T",
        release_group: nil,
        artists: "A",
        date: "2000",
        barcode: "0",
        media: []
      }

      # Empty media list has no frequencies, so the catch-all returns :multi
      assert ReleaseSearchResult.format(result) == :multi
    end

    test "returns :multi for mixed format types" do
      result = %ReleaseSearchResult{
        id: "1",
        title: "T",
        release_group: nil,
        artists: "A",
        date: "2000",
        barcode: "0",
        media: [
          %{format: "CD", disc_count: 1, track_count: 10},
          %{format: "12\" Vinyl", disc_count: 1, track_count: 6},
          %{format: "Digital Media", disc_count: 0, track_count: 12}
        ]
      }

      assert ReleaseSearchResult.format(result) == :multi
    end
  end

  describe "parse_media/1" do
    test "handles empty media list" do
      assert ReleaseSearchResult.parse_media([]) == []
    end

    test "handles missing fields gracefully" do
      media = [%{}]
      parsed = ReleaseSearchResult.parse_media(media)
      assert hd(parsed).format == nil
      assert hd(parsed).track_count == nil
      assert hd(parsed).disc_count == nil
    end
  end
end
