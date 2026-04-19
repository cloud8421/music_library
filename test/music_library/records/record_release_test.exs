defmodule MusicLibrary.Records.RecordReleaseTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Records.Record
  alias MusicLibrary.Records.RecordRelease

  @release_id_1 "0e290154-5375-4f4f-a658-4a92bf02faa5"
  @release_id_2 "3f1cc80f-4507-48a9-899c-c1bda83280c2"
  @release_id_3 "d3f9b9e2-73f5-4b47-a2a7-2c2199aad608"

  defp insert_record(attrs \\ %{}) do
    %Record{
      type: :album,
      title: "Brave",
      musicbrainz_id: Ecto.UUID.generate(),
      genres: ["progressive rock"],
      release_ids: [@release_id_1, @release_id_2],
      cover_hash: "hash-abc",
      purchased_at: ~U[2024-01-15 10:00:00Z]
    }
    |> Record.changeset(attrs)
    |> Repo.insert!()
  end

  defp list_releases(record_id) do
    RecordRelease
    |> where(record_id: ^record_id)
    |> order_by(:release_id)
    |> Repo.all()
  end

  describe "after insert trigger" do
    test "expands release_ids into one row per release" do
      record = insert_record()

      assert [row_1, row_2] = list_releases(record.id)
      assert row_1.record_id == record.id
      assert row_2.record_id == record.id
      assert Enum.sort([row_1.release_id, row_2.release_id]) == [@release_id_1, @release_id_2]
    end

    test "copies cover_hash and purchased_at onto each row" do
      record =
        insert_record(%{cover_hash: "hash-xyz", purchased_at: ~U[2023-06-01 00:00:00Z]})

      rows = list_releases(record.id)

      assert Enum.all?(rows, fn row -> row.cover_hash == "hash-xyz" end)
      assert Enum.all?(rows, fn row -> row.purchased_at == ~U[2023-06-01 00:00:00Z] end)
    end

    test "handles nil cover_hash and purchased_at" do
      record = insert_record(%{cover_hash: nil, purchased_at: nil})

      rows = list_releases(record.id)

      assert length(rows) == 2
      assert Enum.all?(rows, fn row -> row.cover_hash == nil end)
      assert Enum.all?(rows, fn row -> row.purchased_at == nil end)
    end

    test "creates no rows when release_ids is empty" do
      record = insert_record(%{release_ids: []})

      assert list_releases(record.id) == []
    end

    test "isolates rows per record" do
      record_a = insert_record(%{release_ids: [@release_id_1]})
      record_b = insert_record(%{release_ids: [@release_id_2, @release_id_3]})

      assert [%{release_id: @release_id_1}] = list_releases(record_a.id)

      assert [%{release_id: id_a}, %{release_id: id_b}] = list_releases(record_b.id)
      assert Enum.sort([id_a, id_b]) == [@release_id_2, @release_id_3]
    end
  end

  describe "before/after update triggers" do
    test "replace rows when release_ids changes (add, remove, swap)" do
      record = insert_record(%{release_ids: [@release_id_1, @release_id_2]})

      record
      |> Ecto.Changeset.change(release_ids: [@release_id_2, @release_id_3])
      |> Repo.update!()

      ids =
        record.id
        |> list_releases()
        |> Enum.map(& &1.release_id)

      assert ids == [@release_id_2, @release_id_3]
    end

    test "remove all rows when release_ids becomes empty" do
      record = insert_record()

      record
      |> Ecto.Changeset.change(release_ids: [])
      |> Repo.update!()

      assert list_releases(record.id) == []
    end

    test "populate rows when release_ids goes from empty to non-empty" do
      record = insert_record(%{release_ids: []})

      assert list_releases(record.id) == []

      record
      |> Ecto.Changeset.change(release_ids: [@release_id_1])
      |> Repo.update!()

      assert [%{release_id: @release_id_1}] = list_releases(record.id)
    end

    test "propagate cover_hash changes to existing rows" do
      record = insert_record(%{cover_hash: "hash-old"})

      record
      |> Ecto.Changeset.change(cover_hash: "hash-new")
      |> Repo.update!()

      rows = list_releases(record.id)

      assert length(rows) == 2
      assert Enum.all?(rows, fn row -> row.cover_hash == "hash-new" end)
    end

    test "propagate purchased_at changes to existing rows" do
      record = insert_record(%{purchased_at: ~U[2024-01-15 10:00:00Z]})

      record
      |> Ecto.Changeset.change(purchased_at: ~U[2025-02-20 12:00:00Z])
      |> Repo.update!()

      rows = list_releases(record.id)

      assert length(rows) == 2
      assert Enum.all?(rows, fn row -> row.purchased_at == ~U[2025-02-20 12:00:00Z] end)
    end

    test "rewrite rows on unrelated field updates (e.g. title)" do
      record = insert_record()
      before_ids = record.id |> list_releases() |> Enum.map(& &1.release_id)

      record
      |> Ecto.Changeset.change(title: "Brave (Remastered)")
      |> Repo.update!()

      after_ids = record.id |> list_releases() |> Enum.map(& &1.release_id)

      assert after_ids == before_ids
    end
  end

  describe "before delete trigger" do
    test "remove all rows when the record is deleted" do
      record = insert_record()
      assert length(list_releases(record.id)) == 2

      Repo.delete!(record)

      assert list_releases(record.id) == []
    end

    test "only remove rows for the deleted record" do
      record_a = insert_record(%{release_ids: [@release_id_1]})
      record_b = insert_record(%{release_ids: [@release_id_2]})

      Repo.delete!(record_a)

      assert list_releases(record_a.id) == []
      assert [%{release_id: @release_id_2}] = list_releases(record_b.id)
    end
  end
end
