defmodule MusicLibrary.RecordSetsTest do
  use MusicLibrary.DataCase

  import MusicLibrary.Fixtures.Records
  import MusicLibrary.Fixtures.RecordSets

  alias MusicLibrary.RecordSets

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
      assert length(results) == 2

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
      assert {:ok, _} = RecordSets.delete_record_set(set)
      assert_raise Ecto.NoResultsError, fn -> RecordSets.get_record_set!(set.id) end
    end
  end

  describe "add_record_to_set/2" do
    test "adds a record to the set" do
      set = record_set()
      rec = record()

      assert {:ok, updated} = RecordSets.add_record_to_set(set, rec.id)
      assert length(updated.items) == 1
      assert hd(updated.items).record.id == rec.id
    end

    test "returns error on duplicate" do
      set = record_set()
      rec = record()

      {:ok, _} = RecordSets.add_record_to_set(set, rec.id)
      assert {:error, _changeset} = RecordSets.add_record_to_set(set, rec.id)
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
end
