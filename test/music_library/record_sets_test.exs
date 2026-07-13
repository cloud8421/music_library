defmodule MusicLibrary.RecordSetsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records
  import MusicLibrary.Fixtures.RecordSets

  import Ecto.Query, warn: false

  alias MusicLibrary.Records.Record
  alias MusicLibrary.RecordSets
  alias MusicLibrary.RecordSets.RecordSetItem
  alias MusicLibrary.Repo

  describe "search_record_sets/2" do
    test "returns sets matching by name" do
      set = record_set(%{name: "Road Trip Mix"})
      _other = record_set(%{name: "Unrelated"})

      results = RecordSets.search_record_sets("Road Trip")
      assert Enum.any?(results, &(&1.id == set.id))
      refute Enum.any?(results, &(&1.name == "Unrelated"))
    end

    test "returns sets matching by description" do
      set = record_set(%{name: "My Set", description: "Great progressive rock"})
      _other = record_set(%{name: "Other", description: "Nothing here"})

      results = RecordSets.search_record_sets("progressive")
      assert Enum.any?(results, &(&1.id == set.id))
    end

    test "returns sets matching by record title" do
      {set, [rec | _]} = record_set_with_records(1, %{name: "Favorites"})

      results = RecordSets.search_record_sets(rec.title)
      assert Enum.any?(results, &(&1.id == set.id))
    end

    test "returns sets matching by artist name" do
      rec = record_with_artist("Marillion")
      set = record_set(%{name: "Prog"})
      {:ok, _} = RecordSets.add_record_to_set(set, rec.id)

      results = RecordSets.search_record_sets("Marillion")
      assert Enum.any?(results, &(&1.id == set.id))
    end

    test "returns all sets when query is empty" do
      set1 = record_set(%{name: "First"})
      set2 = record_set(%{name: "Second"})

      results = RecordSets.search_record_sets("")
      ids = Enum.map(results, & &1.id)
      assert set1.id in ids
      assert set2.id in ids
    end

    test "respects offset and limit" do
      for i <- 1..5, do: record_set(%{name: "Set #{i}"})

      results = RecordSets.search_record_sets("", limit: 2)
      assert Enum.count_until(results, 3) == 2

      all = RecordSets.search_record_sets("")
      offset_results = RecordSets.search_record_sets("", offset: 2, limit: 2)

      refute Enum.at(all, 0).id == Enum.at(offset_results, 0).id
    end

    test "orders by updated_at desc by default" do
      s1 = record_set(%{name: "Alpha"})
      s2 = record_set(%{name: "Beta"})

      # Manually set timestamps to ensure deterministic ordering
      past = ~U[2024-01-01 00:00:00Z]
      future = ~U[2025-01-01 00:00:00Z]
      Repo.update_all(from(rs in "record_sets", where: rs.id == ^s1.id), set: [updated_at: past])

      Repo.update_all(from(rs in "record_sets", where: rs.id == ^s2.id),
        set: [updated_at: future]
      )

      results = RecordSets.search_record_sets("")
      ids = Enum.map(results, & &1.id)

      # s2 has newer updated_at so it should be first
      assert Enum.find_index(ids, &(&1 == s2.id)) < Enum.find_index(ids, &(&1 == s1.id))
    end

    test "orders alphabetically when order: :alphabetical" do
      record_set(%{name: "Zulu"})
      record_set(%{name: "Alpha"})

      results = RecordSets.search_record_sets("", order: :alphabetical)
      names = Enum.map(results, & &1.name)

      assert Enum.find_index(names, &(&1 == "Alpha")) < Enum.find_index(names, &(&1 == "Zulu"))
    end
  end

  describe "count_record_sets/0 and count_record_sets/1" do
    test "returns total count" do
      assert RecordSets.count_record_sets() == 0

      record_set(%{name: "One"})
      record_set(%{name: "Two"})

      assert RecordSets.count_record_sets() == 2
    end

    test "returns count matching query" do
      record_set(%{name: "Road Trip"})
      record_set(%{name: "Sunday Morning"})

      assert RecordSets.count_record_sets("Road") == 1
      assert RecordSets.count_record_sets("") == 2
    end
  end

  describe "create_record_set/1" do
    test "creates with valid attrs" do
      assert {:ok, set} = RecordSets.create_record_set(%{name: "My Set"})
      assert set.name == "My Set"
      assert set.items == []
    end

    test "returns error changeset with invalid attrs" do
      assert {:error, changeset} = RecordSets.create_record_set(%{name: nil})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "update_record_set/2" do
    test "updates with valid attrs" do
      set = record_set(%{name: "Old Name"})
      assert {:ok, updated} = RecordSets.update_record_set(set, %{name: "New Name"})
      assert updated.name == "New Name"
    end
  end

  describe "delete_record_set/1" do
    test "deletes the record set" do
      set = record_set()
      assert {:ok, deleted} = RecordSets.delete_record_set(set)
      assert_raise Ecto.NoResultsError, fn -> RecordSets.get_record_set!(deleted.id) end
    end
  end

  describe "add_record_to_set/2" do
    test "adds a record to the set" do
      set = record_set()
      rec = record()

      assert {:ok, updated} = RecordSets.add_record_to_set(set, rec.id)
      assert Enum.count_until(updated.items, 2) == 1
      assert hd(updated.items).record.id == rec.id
    end

    test "returns error on duplicate" do
      set = record_set()
      rec = record()

      {:ok, _} = RecordSets.add_record_to_set(set, rec.id)
      assert {:error, changeset} = RecordSets.add_record_to_set(set, rec.id)
      assert %{record_set_id: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "remove_record_from_set/2" do
    test "removes a record and recompacts positions" do
      {set, [r1, r2, r3]} = record_set_with_records(3)

      {:ok, updated} = RecordSets.remove_record_from_set(set, r2.id)

      record_ids = Enum.map(updated.items, & &1.record.id)
      assert r1.id in record_ids
      assert r3.id in record_ids
      refute r2.id in record_ids

      positions = Enum.map(updated.items, & &1.position)
      assert positions == [0, 1]
    end
  end

  describe "reorder_records_in_set/2" do
    test "reorders records according to the given order" do
      {set, [r1, r2, r3]} = record_set_with_records(3)

      {:ok, updated} = RecordSets.reorder_records_in_set(set, [r3.id, r1.id, r2.id])

      ids_in_order = Enum.map(updated.items, & &1.record.id)
      assert ids_in_order == [r3.id, r1.id, r2.id]
    end

    test "no-ops when order is unchanged" do
      {set, [r1, r2, r3]} = record_set_with_records(3)

      {:ok, updated} = RecordSets.reorder_records_in_set(set, [r1.id, r2.id, r3.id])

      ids_in_order = Enum.map(updated.items, & &1.record.id)
      assert ids_in_order == [r1.id, r2.id, r3.id]
    end
  end

  describe "move_record_in_set/3" do
    test "moves a record up" do
      {set, [r1, r2 | _]} = record_set_with_records(3)

      {:ok, updated} = RecordSets.move_record_in_set(set, r2.id, :up)

      ids_in_order = Enum.map(updated.items, & &1.record.id)
      assert Enum.at(ids_in_order, 0) == r2.id
      assert Enum.at(ids_in_order, 1) == r1.id
    end

    test "moves a record down" do
      {set, [r1, r2 | _]} = record_set_with_records(3)

      {:ok, updated} = RecordSets.move_record_in_set(set, r1.id, :down)

      ids_in_order = Enum.map(updated.items, & &1.record.id)
      assert Enum.at(ids_in_order, 0) == r2.id
      assert Enum.at(ids_in_order, 1) == r1.id
    end

    test "no-ops at boundaries" do
      {set, [r1, _, r3]} = record_set_with_records(3)

      {:ok, moved_up} = RecordSets.move_record_in_set(set, r1.id, :up)
      assert Enum.map(moved_up.items, & &1.record.id) == Enum.map(set.items, & &1.record.id)

      {:ok, moved_down} = RecordSets.move_record_in_set(set, r3.id, :down)
      assert Enum.map(moved_down.items, & &1.record.id) == Enum.map(set.items, & &1.record.id)
    end
  end

  describe "empty_record_set/1" do
    test "removes all items and returns the empty set" do
      {set, [_r1, _r2, _r3]} = record_set_with_records(3)

      {:ok, updated} = RecordSets.empty_record_set(set)
      assert updated.items == []
      # Set metadata preserved
      assert updated.name == set.name
      assert updated.description == set.description
      # Items are actually deleted from DB
      assert [] =
               from(i in RecordSetItem, where: i.record_set_id == ^set.id)
               |> Repo.all()
    end

    test "is a no-op on already-empty sets" do
      set = record_set()
      assert set.items == []

      {:ok, updated} = RecordSets.empty_record_set(set)
      assert updated.items == []
    end
  end

  describe "list_record_set_choices_for_record/1" do
    test "returns lightweight choices and member set IDs" do
      set1 = record_set(%{name: "Beta"})
      set2 = record_set(%{name: "Alpha"})
      set3 = record_set(%{name: "Gamma"})
      rec = record()

      {:ok, _} = RecordSets.add_record_to_set(set1, rec.id)

      {choices, member_set_ids} = RecordSets.list_record_set_choices_for_record(rec.id)

      # Choices are lightweight maps with only :id and :name
      assert Enum.count_until(choices, 4) >= 3

      choice = hd(choices)
      assert is_map_key(choice, :id)
      assert is_map_key(choice, :name)
      refute is_map_key(choice, :description)
      refute is_map_key(choice, :items)

      # Sorted by name COLLATE NOCASE, then name, then id
      names = Enum.map(choices, & &1.name)
      assert Enum.find_index(names, &(&1 == "Alpha")) < Enum.find_index(names, &(&1 == "Beta"))
      assert Enum.find_index(names, &(&1 == "Beta")) < Enum.find_index(names, &(&1 == "Gamma"))

      # Member set IDs contain only the set the record belongs to
      assert MapSet.equal?(member_set_ids, MapSet.new([set1.id]))
      refute MapSet.member?(member_set_ids, set2.id)
      refute MapSet.member?(member_set_ids, set3.id)
    end

    test "returns empty member set IDs for record without memberships" do
      _set = record_set()
      rec = record()

      {choices, member_set_ids} = RecordSets.list_record_set_choices_for_record(rec.id)

      # At least one choice should exist from the created set
      assert choices != []
      assert MapSet.equal?(member_set_ids, MapSet.new())
    end

    test "picker functions return correct shape without preloading items or records" do
      for _i <- 1..5, do: record_set()
      rec = record()

      {choices, member_set_ids} = RecordSets.list_record_set_choices_for_record(rec.id)

      assert is_list(choices)
      assert is_map_key(hd(choices), :id)
      assert is_map_key(hd(choices), :name)
      refute is_map_key(hd(choices), :description)
      refute is_map_key(hd(choices), :items)
      assert is_struct(member_set_ids, MapSet)
    end
  end

  describe "add_record_to_sets/2" do
    test "adds a record to multiple sets in one operation" do
      set1 = record_set()
      set2 = record_set()
      set3 = record_set()
      rec = record()

      assert {:ok, 3} =
               RecordSets.add_record_to_sets(rec, [set1.id, set2.id, set3.id])

      # Verify memberships via context
      member_sets = RecordSets.list_record_sets_for_record(rec.id)
      member_ids = Enum.map(member_sets, & &1.id)
      assert set1.id in member_ids
      assert set2.id in member_ids
      assert set3.id in member_ids

      # Verify positions are sequential
      for set <- [set1, set2, set3] do
        updated = RecordSets.get_record_set!(set.id)
        assert Enum.count_until(updated.items, 2) == 1
        assert hd(updated.items).position == 0
      end
    end

    test "assigns the next position in each set" do
      {set, [_existing]} = record_set_with_records(1)
      rec = record()

      assert {:ok, 1} = RecordSets.add_record_to_sets(rec, [set.id])

      updated = RecordSets.get_record_set!(set.id)
      assert Enum.count_until(updated.items, 3) == 2

      positions = Enum.map(updated.items, & &1.position)
      assert Enum.sort(positions) == [0, 1]
    end

    test "deduplicates submitted set IDs" do
      set1 = record_set()
      set2 = record_set()
      rec = record()

      assert {:ok, 2} =
               RecordSets.add_record_to_sets(rec, [set1.id, set1.id, set2.id, set2.id])

      member_sets = RecordSets.list_record_sets_for_record(rec.id)
      assert Enum.count_until(member_sets, 3) == 2
    end

    test "skips already-existing memberships and returns inserted count only" do
      set1 = record_set()
      set2 = record_set()
      rec = record()

      {:ok, _} = RecordSets.add_record_to_set(set1, rec.id)

      # Submit both sets, set1 already has it
      assert {:ok, 1} = RecordSets.add_record_to_sets(rec, [set1.id, set2.id])

      member_sets = RecordSets.list_record_sets_for_record(rec.id)
      assert Enum.count_until(member_sets, 3) == 2
    end

    test "returns zero inserted count when record already belongs to all sets" do
      set1 = record_set()
      rec = record()

      {:ok, _} = RecordSets.add_record_to_set(set1, rec.id)

      assert {:ok, 0} = RecordSets.add_record_to_sets(rec, [set1.id])
    end

    test "handles stale memberships created between load and submit" do
      set1 = record_set()
      set2 = record_set()
      rec = record()

      # Simulate stale state: set1 membership added after picker load
      {:ok, _} = RecordSets.add_record_to_set(set1, rec.id)

      assert {:ok, 1} = RecordSets.add_record_to_sets(rec, [set1.id, set2.id])

      member_sets = RecordSets.list_record_sets_for_record(rec.id)
      assert Enum.count_until(member_sets, 3) == 2
    end

    test "returns error for empty list after normalization" do
      rec = record()

      assert {:error, :empty_selection} = RecordSets.add_record_to_sets(rec, [])
    end

    test "returns error for malformed set IDs" do
      rec = record()

      assert {:error, {:invalid_set_ids, ["not-a-uuid"]}} =
               RecordSets.add_record_to_sets(rec, ["not-a-uuid"])
    end

    test "returns error for mixed valid and malformed IDs" do
      set = record_set()
      rec = record()

      assert {:error, {:invalid_set_ids, ["bad"]}} =
               RecordSets.add_record_to_sets(rec, [set.id, "bad"])
    end

    test "returns error for missing record" do
      set = record_set()

      assert {:error, :record_not_found} =
               RecordSets.add_record_to_sets(%Record{id: Ecto.UUID.generate()}, [set.id])
    end

    test "returns error for missing set IDs" do
      rec = record()
      missing_id = Ecto.UUID.generate()

      assert {:error, {:record_sets_not_found, [^missing_id]}} =
               RecordSets.add_record_to_sets(rec, [missing_id])
    end

    test "returns error for mixed valid and missing set IDs with no partial writes" do
      set1 = record_set()
      rec = record()
      missing_id = Ecto.UUID.generate()

      assert {:error, {:record_sets_not_found, [^missing_id]}} =
               RecordSets.add_record_to_sets(rec, [set1.id, missing_id])

      # No partial writes
      member_sets = RecordSets.list_record_sets_for_record(rec.id)
      assert Enum.empty?(member_sets)
    end

    test "correctly handles 25-set bulk add in one call" do
      sets = for _i <- 1..25, do: record_set()
      rec = record()

      set_ids = Enum.map(sets, & &1.id)
      assert {:ok, 25} = RecordSets.add_record_to_sets(rec, set_ids)

      # All 25 memberships are verified
      member_sets = RecordSets.list_record_sets_for_record(rec.id)
      assert Enum.count_until(member_sets, 26) == 25
    end
  end

  describe "add_record_to_set/2 preserves existing behaviour after refactor" do
    test "adds a record to the set" do
      set = record_set()
      rec = record()

      assert {:ok, updated} = RecordSets.add_record_to_set(set, rec.id)
      assert Enum.count_until(updated.items, 2) == 1
      assert hd(updated.items).record.id == rec.id
    end

    test "returns error on duplicate with changeset" do
      set = record_set()
      rec = record()

      {:ok, _} = RecordSets.add_record_to_set(set, rec.id)

      assert {:error, changeset} = RecordSets.add_record_to_set(set, rec.id)
      assert %{record_set_id: ["has already been taken"]} = errors_on(changeset)
    end
  end
end
