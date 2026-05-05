defmodule MusicLibrary.Records.SearchTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Records.Search
  alias MusicLibrary.Records.SearchIndex

  defp create_records(_) do
    records = [
      record_with_artist("Marillion", %{title: "Brave", format: :vinyl}),
      record_with_artist("Marillion", %{title: "Brave (Live)", format: :cd, type: :live}),
      record_with_artist("Marillion", %{title: "Afraid of Sunlight"}),
      record_with_artist("Airbag", %{title: "The Greatest Show on Earth"}),
      record_with_artist("Airbag (AU)", %{title: "Libertad"})
    ]

    %{records: records}
  end

  defp search(query, limit, offset) do
    SearchIndex
    |> Search.search_records(query, limit: limit, offset: offset, order: :alphabetical)
    |> Enum.map(& &1.id)
  end

  describe "search_records/2" do
    setup [:create_records]

    test "untagged search (with limit and offset)", %{
      records: [brave_vinyl, brave_live_cd | _rest]
    } do
      assert [brave_vinyl.id, brave_live_cd.id] == search("brave", 10, 0)
      assert [brave_vinyl.id] == search("brave", 1, 0)
      assert [brave_live_cd.id] == search("brave", 1, 1)
    end

    test "tagged search - album", %{records: [_brave_vinyl, brave_live_cd | _rest]} do
      assert [brave_live_cd.id] == search(~s(album:"Brave \(Live\)"), 10, 0)
    end

    test "tagged search - artist", %{records: [_, _, _, greatest_show_on_earth, libertad]} do
      assert [greatest_show_on_earth.id, libertad.id] == search("artist:airbag", 10, 0)
      assert [libertad.id] == search(~s(artist:"airbag \(AU\)"), 10, 0)
    end

    test "tagged search - format", %{records: [_brave_vinyl, brave_live_cd | _rest]} do
      assert [brave_live_cd.id] == search("brave format:cd", 10, 0)
    end

    test "tagged search - type", %{records: [_brave_vinyl, brave_live_cd | _rest]} do
      assert [brave_live_cd.id] == search("brave type:live", 10, 0)
    end

    test "tagged search - mbid", %{records: [_, _, _, greatest_show_on_earth, libertad]} do
      [airbag_mbid] = Enum.map(greatest_show_on_earth.artists, fn a -> a.musicbrainz_id end)
      [airbag_au_mbid] = Enum.map(libertad.artists, fn a -> a.musicbrainz_id end)

      assert [greatest_show_on_earth.id] == search("mbid:#{airbag_mbid}", 10, 0)
      assert [libertad.id] == search("mbid:#{airbag_au_mbid}", 10, 0)
    end

    test "bare special characters return empty results without crashing" do
      for char <- ["|", ";", "&", "+", "#", "@"] do
        assert [] == search(char, 10, 0)
      end
    end

    test "special characters mixed with normal words return matching results" do
      assert [] == search("brave &", 10, 0)
      assert [] == search("hello ;", 10, 0)
    end
  end

  describe "search_records_count/2" do
    setup [:create_records]

    test "untagged search" do
      assert 2 == Search.search_records_count(SearchIndex, "brave")
    end

    test "tagged search - album" do
      assert 1 == Search.search_records_count(SearchIndex, ~s(album:"Brave \(Live\)"))
    end

    test "tagged search - artist" do
      assert 2 == Search.search_records_count(SearchIndex, "artist:airbag")
      assert 1 == Search.search_records_count(SearchIndex, ~s(artist:"airbag \(AU\)"))
    end

    test "tagged search - format" do
      assert 1 == Search.search_records_count(SearchIndex, "brave format:cd")
    end

    test "tagged search - type" do
      assert 1 == Search.search_records_count(SearchIndex, "brave type:live")
    end

    test "tagged search - mbid", %{records: [_, _, _, greatest_show_on_earth, libertad]} do
      [airbag_mbid] = Enum.map(greatest_show_on_earth.artists, fn a -> a.musicbrainz_id end)
      [airbag_au_mbid] = Enum.map(libertad.artists, fn a -> a.musicbrainz_id end)

      assert 1 ==
               Search.search_records_count(SearchIndex, "mbid:#{airbag_mbid}")

      assert 1 == Search.search_records_count(SearchIndex, "mbid:#{airbag_au_mbid}")
    end

    test "bare special characters do not crash and return zero" do
      for char <- ["|", ";", "&", "+", "#", "@"] do
        assert 0 == Search.search_records_count(SearchIndex, char)
      end
    end

    test "special characters mixed with normal words do not crash" do
      assert 0 == Search.search_records_count(SearchIndex, "brave &")
      assert 0 == Search.search_records_count(SearchIndex, "hello ;")
    end
  end
end
