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

    test "it respects limit" do
      assert [%{title: "Brave"}] = Collection.search_records("brave", limit: 1)
    end

    test "it respects offset" do
      [first_match] = Collection.search_records("brave", limit: 1)
      [second_match] = Collection.search_records("brave", limit: 1, offset: 1)
      assert first_match !== second_match
    end

    test "it respects order" do
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
      random_record = Collection.get_latest_record!()
      collection_ids = Enum.map(collection, & &1.id)

      assert random_record.id in collection_ids
    end
  end
end
