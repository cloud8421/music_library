defmodule MusicLibrary.CollectionTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records

  alias MusicLibrary.Collection

  defp fill_collection(_) do
    # Purchased dates are in ascending order
    records = [
      record_with_artist("Marillion", %{
        title: "Brave",
        format: :cd,
        type: :album,
        purchased_at: ~U[2024-12-27 16:50:57Z]
      }),
      record_with_artist("Marillion", %{
        title: "Brave (Remastered)",
        format: :vinyl,
        type: :live,
        purchased_at: ~U[2024-12-28 16:50:57Z]
      }),
      record_with_artist("Marillion", %{
        format: :vinyl,
        type: :ep,
        purchased_at: ~U[2024-12-29 16:50:57Z]
      }),
      record_with_artist("Marillion", %{
        title: "Brave",
        format: :dvd,
        purchased_at: nil,
        type: :live
      })
    ]

    %{collection: records}
  end

  describe "search_records/2" do
    setup [:fill_collection]

    test "returns matching records, excluding wishlisted records" do
      assert [%{title: "Brave"}, %{title: "Brave (Remastered)"}] =
               Collection.search_records("brave")
    end

    test "respects limit" do
      assert [%{title: "Brave"}] = Collection.search_records("brave", limit: 1)
    end

    test "respects offset" do
      [first_match] = Collection.search_records("brave", limit: 1)
      [second_match] = Collection.search_records("brave", limit: 1, offset: 1)
      assert first_match !== second_match
    end

    test "respects order" do
      assert [%{title: "Brave (Remastered)"}, %{title: "Brave"}] =
               Collection.search_records("brave", order: :purchase)

      assert [%{title: "Brave"}, %{title: "Brave (Remastered)"}] =
               Collection.search_records("brave", order: :alphabetical)
    end
  end

  describe "search_records_count/1" do
    setup [:fill_collection]

    test "returns the count of matching records, excluding wishlisted records" do
      assert 2 == Collection.search_records_count("brave")
    end
  end

  describe "count_records_by_format/0" do
    setup [:fill_collection]

    test "returns the count of records in the collection by format, excluding wishlisted records" do
      assert [vinyl: 2, cd: 1] == Collection.count_records_by_format()
    end
  end

  describe "count_records_by_type/0" do
    setup [:fill_collection]

    test "returns the count of records in the collection by type, excluding wishlisted records" do
      assert [album: 1, ep: 1, live: 1] == Collection.count_records_by_type()
    end
  end

  describe "group_records_by_release_group/1" do
    test "wraps single records in {:single, record} tuples" do
      record =
        record_with_artist("Marillion", %{
          title: "Brave",
          release_date: "2020",
          purchased_at: ~U[2024-12-27 16:50:57Z]
        })

      assert [{:single, ^record}] = Collection.group_records_by_release_group([record])
    end

    test "groups records sharing the same musicbrainz_id" do
      shared_mbid = Ecto.UUID.generate()

      cd =
        record_with_artist("Marillion", %{
          title: "Brave",
          musicbrainz_id: shared_mbid,
          format: :cd,
          release_date: "2020",
          purchased_at: ~U[2024-12-27 16:50:57Z]
        })

      vinyl =
        record_with_artist("Marillion", %{
          title: "Brave",
          musicbrainz_id: shared_mbid,
          format: :vinyl,
          release_date: "2020",
          purchased_at: ~U[2024-12-28 16:50:57Z]
        })

      result = Collection.group_records_by_release_group([cd, vinyl])

      assert [{:group, %{representative: rep, records: records}}] = result
      assert rep.id == cd.id
      assert length(records) == 2
      # Sorted by purchased_at ascending
      assert Enum.map(records, & &1.id) == [cd.id, vinyl.id]
    end

    test "sorts groups by release_date descending" do
      older =
        record_with_artist("Marillion", %{
          title: "Script for a Jester's Tear",
          release_date: "1983",
          purchased_at: ~U[2024-12-27 16:50:57Z]
        })

      newer =
        record_with_artist("Marillion", %{
          title: "Brave",
          release_date: "1994",
          purchased_at: ~U[2024-12-28 16:50:57Z]
        })

      result = Collection.group_records_by_release_group([older, newer])

      assert [{:single, first}, {:single, second}] = result
      assert first.id == newer.id
      assert second.id == older.id
    end

    test "returns empty list for empty input" do
      assert [] == Collection.group_records_by_release_group([])
    end
  end

  describe "count_records_by_release_year/1" do
    test "returns counts grouped by release year, ordered by count descending" do
      record_with_artist("Artist A", %{
        release_date: "1994-09-13",
        purchased_at: ~U[2024-12-27 16:50:57Z]
      })

      record_with_artist("Artist B", %{
        release_date: "1994-03-01",
        purchased_at: ~U[2024-12-28 16:50:57Z]
      })

      record_with_artist("Artist C", %{
        release_date: "2020",
        purchased_at: ~U[2024-12-29 16:50:57Z]
      })

      assert [{"1994", 2}, {"2020", 1}] = Collection.count_records_by_release_year()
    end

    test "excludes wishlisted records" do
      record_with_artist("Artist A", %{
        release_date: "2020",
        purchased_at: ~U[2024-12-27 16:50:57Z]
      })

      record_with_artist("Artist B", %{
        release_date: "2020",
        purchased_at: nil
      })

      assert [{"2020", 1}] = Collection.count_records_by_release_year()
    end

    test "excludes records without a release date" do
      record_with_artist("Artist A", %{
        release_date: "2020",
        purchased_at: ~U[2024-12-27 16:50:57Z]
      })

      record_with_artist("Artist B", %{
        release_date: nil,
        purchased_at: ~U[2024-12-28 16:50:57Z]
      })

      record_with_artist("Artist C", %{
        release_date: "",
        purchased_at: ~U[2024-12-29 16:50:57Z]
      })

      assert [{"2020", 1}] = Collection.count_records_by_release_year()
    end

    test "respects limit" do
      record_with_artist("Artist A", %{
        release_date: "1994",
        purchased_at: ~U[2024-12-27 16:50:57Z]
      })

      record_with_artist("Artist B", %{
        release_date: "1994",
        purchased_at: ~U[2024-12-28 16:50:57Z]
      })

      record_with_artist("Artist C", %{
        release_date: "2020",
        purchased_at: ~U[2024-12-29 16:50:57Z]
      })

      assert [{"1994", 2}] = Collection.count_records_by_release_year(limit: 1)
    end
  end

  describe "search_records/2 with release_year" do
    test "filters by release year" do
      record_with_artist("Artist A", %{
        title: "Album 1994",
        release_date: "1994-09-13",
        purchased_at: ~U[2024-12-27 16:50:57Z]
      })

      record_with_artist("Artist B", %{
        title: "Album 2020",
        release_date: "2020",
        purchased_at: ~U[2024-12-28 16:50:57Z]
      })

      assert [%{title: "Album 1994"}] = Collection.search_records("release_year:1994")
      assert [%{title: "Album 2020"}] = Collection.search_records("release_year:2020")
      assert [] = Collection.search_records("release_year:2000")
    end
  end

  describe "get_records_on_this_day/1" do
    test "returns collected records matching the month-day of the given date" do
      record_with_artist("Marillion", %{
        title: "Brave",
        release_date: "1994-04-15",
        purchased_at: ~U[2024-12-27 16:50:57Z]
      })

      record_with_artist("Marillion", %{
        title: "Misplaced Childhood",
        release_date: "1985-06-17",
        purchased_at: ~U[2024-12-28 16:50:57Z]
      })

      assert [%{title: "Brave"}] = Collection.get_records_on_this_day(~D[2026-04-15])
    end

    test "excludes records with bare-year release dates" do
      record_with_artist("Marillion", %{
        title: "Brave",
        release_date: "1994-04-15",
        purchased_at: ~U[2024-12-27 16:50:57Z]
      })

      record_with_artist("Marillion", %{
        title: "Magician",
        release_date: "1970",
        purchased_at: ~U[2024-10-03 07:52:33Z]
      })

      results = Collection.get_records_on_this_day(~D[2026-04-15])

      assert [%{title: "Brave"}] = results
    end

    test "excludes records with year-month release dates" do
      record_with_artist("Marillion", %{
        title: "Brave",
        release_date: "1994-04-15",
        purchased_at: ~U[2024-12-27 16:50:57Z]
      })

      record_with_artist("Porcupine Tree", %{
        title: "Up the Downstair",
        release_date: "1993-04",
        purchased_at: ~U[2024-12-28 16:50:57Z]
      })

      results = Collection.get_records_on_this_day(~D[2026-04-15])

      assert [%{title: "Brave"}] = results
    end

    test "excludes wishlisted records" do
      record_with_artist("Marillion", %{
        title: "Brave",
        release_date: "1994-04-15",
        purchased_at: ~U[2024-12-27 16:50:57Z]
      })

      record_with_artist("Marillion", %{
        title: "Anoraknophobia",
        release_date: "2001-04-15",
        purchased_at: nil
      })

      assert [%{title: "Brave"}] = Collection.get_records_on_this_day(~D[2026-04-15])
    end
  end

  describe "collected_artist_ids/0" do
    setup [:fill_collection]

    test "returns musicbrainz_ids for artists on collected records" do
      result = Collection.collected_artist_ids()

      assert is_struct(result, MapSet)
      assert MapSet.size(result) > 0
    end

    test "does not include artists only on wishlisted records" do
      wishlisted =
        record_with_artist("Wishlist Only Artist", %{
          title: "Not Purchased",
          purchased_at: nil
        })

      wishlisted_artist = hd(wishlisted.artists)
      result = Collection.collected_artist_ids()

      refute MapSet.member?(result, wishlisted_artist.musicbrainz_id)
    end
  end

  describe "get_latest_record!/0" do
    setup [:fill_collection]

    test "returns the most recently purchased record" do
      expected_record = record(%{purchased_at: DateTime.utc_now()})
      most_recent_purchase = Collection.get_latest_record!()

      assert expected_record.id == most_recent_purchase.id
    end
  end

  describe "get_random_record!/0" do
    setup [:fill_collection]

    test "returns a random record", %{collection: collection} do
      # NOTE: we can't control randomness in the test, because the `RANDOM()` function
      # in SQLite doesn't support a seed.
      random_record = Collection.get_random_record!()
      collection_ids = Enum.map(collection, & &1.id)

      assert random_record.id in collection_ids
    end
  end

  describe "collection_summary/0" do
    test "returns empty string and zero count when collection is empty" do
      assert Collection.collection_summary() == {"", 0}
    end

    test "returns one line per collected record with record count" do
      record_with_artist("Radiohead", %{
        title: "OK Computer",
        format: :cd,
        type: :album,
        genres: ["alternative rock", "art rock"],
        release_date: "1997-06-16",
        purchased_at: ~U[2024-01-01 00:00:00Z]
      })

      record_with_artist("Pink Floyd", %{
        title: "The Dark Side of the Moon",
        format: :vinyl,
        type: :album,
        genres: ["progressive rock"],
        release_date: "1973-03-01",
        purchased_at: ~U[2024-01-02 00:00:00Z]
      })

      {summary, record_count} = Collection.collection_summary()
      lines = String.split(summary, "\n")

      assert record_count == 2
      assert length(lines) == 2

      assert Enum.any?(lines, fn line ->
               line =~ "Radiohead" and line =~ "OK Computer" and
                 line =~ "1997-06-16" and line =~ "cd" and line =~ "album" and
                 line =~ "alternative rock, art rock"
             end)

      assert Enum.any?(lines, fn line ->
               line =~ "Pink Floyd" and line =~ "The Dark Side of the Moon" and
                 line =~ "1973-03-01" and line =~ "vinyl" and line =~ "album" and
                 line =~ "progressive rock"
             end)
    end

    test "deduplicates records with same musicbrainz_id and merges formats" do
      mbid = Ecto.UUID.generate()

      record_with_artist("AC/DC", %{
        title: "Highway to Hell",
        format: :cd,
        type: :album,
        genres: ["hard rock", "rock"],
        release_date: "1979-07-27",
        musicbrainz_id: mbid,
        purchased_at: ~U[2024-01-01 00:00:00Z]
      })

      record_with_artist("AC/DC", %{
        title: "Highway to Hell",
        format: :vinyl,
        type: :album,
        genres: ["hard rock", "rock"],
        release_date: "1979-07-27",
        musicbrainz_id: mbid,
        purchased_at: ~U[2024-01-02 00:00:00Z]
      })

      {summary, record_count} = Collection.collection_summary()
      lines = String.split(summary, "\n")

      assert record_count == 1
      assert length(lines) == 1

      line = hd(lines)
      assert line =~ "cd"
      assert line =~ "vinyl"
    end

    test "caps genres to 3 per record" do
      record_with_artist("ABC", %{
        title: "The Lexicon of Love",
        format: :vinyl,
        type: :album,
        genres: ~w[dance dance-pop disco electronic new-wave pop synth-pop],
        release_date: "1982-06-21",
        purchased_at: ~U[2024-01-01 00:00:00Z]
      })

      {summary, _count} = Collection.collection_summary()
      [genres_str] = Regex.run(~r/\[(.+)\]/, summary, capture: :all_but_first)
      genre_count = genres_str |> String.split(", ") |> length()

      assert genre_count == 3
    end

    test "omits genre brackets when genres are empty" do
      record_with_artist("Radiohead", %{
        title: "OK Computer",
        format: :cd,
        type: :album,
        genres: [],
        release_date: "1997-06-16",
        purchased_at: ~U[2024-01-01 00:00:00Z]
      })

      {summary, _count} = Collection.collection_summary()
      refute summary =~ "["
      refute summary =~ "]"
    end

    test "excludes wishlist records" do
      record_with_artist("Radiohead", %{
        title: "OK Computer",
        purchased_at: ~U[2024-01-01 00:00:00Z]
      })

      record_with_artist("Pink Floyd", %{
        title: "Wish You Were Here",
        purchased_at: nil
      })

      {summary, record_count} = Collection.collection_summary()
      assert record_count == 1
      assert summary =~ "OK Computer"
      refute summary =~ "Wish You Were Here"
    end
  end
end
