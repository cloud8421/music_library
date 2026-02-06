defmodule MusicLibrary.RecordSets do
  import Ecto.Query, warn: false

  alias MusicLibrary.RecordSets.{RecordSet, RecordSetItem}
  alias MusicLibrary.Repo

  def list_record_sets(opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)
    limit = Keyword.get(opts, :limit, 20)

    from(rs in RecordSet,
      order_by: [desc: rs.updated_at],
      offset: ^offset,
      limit: ^limit,
      preload: [items: :record]
    )
    |> Repo.all()
  end

  def count_record_sets do
    Repo.aggregate(RecordSet, :count)
  end

  def count_record_sets(query) do
    record_sets_search_query(query)
    |> Repo.aggregate(:count)
  end

  def search_record_sets(query, opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)
    limit = Keyword.get(opts, :limit, 20)

    record_sets_search_query(query)
    |> order_by([rs], desc: rs.updated_at)
    |> offset(^offset)
    |> limit(^limit)
    |> preload(items: :record)
    |> Repo.all()
  end

  def get_record_set!(id) do
    RecordSet
    |> Repo.get!(id)
    |> Repo.preload(items: :record)
  end

  def create_record_set(attrs) do
    %RecordSet{}
    |> RecordSet.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, record_set} -> {:ok, Repo.preload(record_set, items: :record)}
      error -> error
    end
  end

  def update_record_set(%RecordSet{} = record_set, attrs) do
    record_set
    |> RecordSet.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, record_set} -> {:ok, Repo.preload(record_set, [items: :record], force: true)}
      error -> error
    end
  end

  def delete_record_set(%RecordSet{} = record_set) do
    Repo.delete(record_set)
  end

  def change_record_set(%RecordSet{} = record_set, attrs \\ %{}) do
    RecordSet.changeset(record_set, attrs)
  end

  def add_record_to_set(%RecordSet{} = record_set, record_id) do
    next_position =
      from(i in RecordSetItem,
        where: i.record_set_id == ^record_set.id,
        select: coalesce(max(i.position), -1)
      )
      |> Repo.one!()
      |> Kernel.+(1)

    %RecordSetItem{}
    |> RecordSetItem.changeset(%{position: next_position})
    |> Ecto.Changeset.put_change(:record_set_id, record_set.id)
    |> Ecto.Changeset.put_change(:record_id, record_id)
    |> Ecto.Changeset.unique_constraint([:record_set_id, :record_id])
    |> Repo.insert()
    |> case do
      {:ok, _item} -> {:ok, get_record_set!(record_set.id)}
      error -> error
    end
  end

  def remove_record_from_set(%RecordSet{} = record_set, record_id) do
    item =
      from(i in RecordSetItem,
        where: i.record_set_id == ^record_set.id and i.record_id == ^record_id
      )
      |> Repo.one!()

    Repo.delete(item)

    recompact_positions(record_set.id)

    {:ok, get_record_set!(record_set.id)}
  end

  def move_record_in_set(%RecordSet{} = record_set, record_id, direction)
      when direction in [:up, :down] do
    items =
      from(i in RecordSetItem,
        where: i.record_set_id == ^record_set.id,
        order_by: [asc: i.position]
      )
      |> Repo.all()

    index = Enum.find_index(items, fn i -> i.record_id == record_id end)

    swap_index =
      case direction do
        :up -> index - 1
        :down -> index + 1
      end

    if index && swap_index >= 0 && swap_index < length(items) do
      item_a = Enum.at(items, index)
      item_b = Enum.at(items, swap_index)

      Repo.transaction(fn ->
        item_a
        |> Ecto.Changeset.change(position: item_b.position)
        |> Repo.update!()

        item_b
        |> Ecto.Changeset.change(position: item_a.position)
        |> Repo.update!()
      end)
    end

    {:ok, get_record_set!(record_set.id)}
  end

  defp record_sets_search_query(""), do: from(rs in RecordSet)

  defp record_sets_search_query(query) do
    like_query = "%#{query}%"

    from(rs in RecordSet,
      where:
        like(rs.name, ^like_query) or
          like(rs.description, ^like_query) or
          fragment(
            """
            EXISTS (
              SELECT 1 FROM record_set_items AS i
              JOIN records AS r ON r.id = i.record_id
              WHERE i.record_set_id = ?
              AND (
                r.title LIKE ?
                OR EXISTS (
                  SELECT 1 FROM json_each(r.artists)
                  WHERE json_extract(value, '$.name') LIKE ?
                )
              )
            )
            """,
            rs.id,
            ^like_query,
            ^like_query
          )
    )
  end

  defp recompact_positions(record_set_id) do
    items =
      from(i in RecordSetItem,
        where: i.record_set_id == ^record_set_id,
        order_by: [asc: i.position]
      )
      |> Repo.all()

    Enum.with_index(items, fn item, index ->
      if item.position != index do
        item
        |> Ecto.Changeset.change(position: index)
        |> Repo.update!()
      end
    end)
  end
end
