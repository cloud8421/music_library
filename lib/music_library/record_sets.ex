defmodule MusicLibrary.RecordSets do
  import Ecto.Query, warn: false

  alias MusicLibrary.RecordSets.{RecordSet, RecordSetItem}
  alias MusicLibrary.Repo

  @pagination Application.compile_env!(:music_library, :pagination)

  @spec list_record_sets(MusicLibrary.Types.pagination_opts()) :: [RecordSet.t()]
  def list_record_sets(opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)
    limit = Keyword.get(opts, :limit, @pagination[:default_page_size])

    from(rs in RecordSet,
      order_by: [desc: rs.updated_at],
      offset: ^offset,
      limit: ^limit,
      preload: [items: :record]
    )
    |> Repo.all()
  end

  @spec count_record_sets() :: non_neg_integer()
  def count_record_sets do
    Repo.aggregate(RecordSet, :count)
  end

  @spec count_record_sets(String.t()) :: non_neg_integer()
  def count_record_sets(query) do
    record_sets_search_query(query)
    |> Repo.aggregate(:count)
  end

  @spec search_record_sets(String.t(), MusicLibrary.Types.pagination_opts()) :: [RecordSet.t()]
  def search_record_sets(query, opts \\ []) do
    offset = Keyword.get(opts, :offset, 0)
    limit = Keyword.get(opts, :limit, @pagination[:default_page_size])
    order = Keyword.get(opts, :order, :updated_at)

    record_sets_search_query(query)
    |> apply_order(order)
    |> offset(^offset)
    |> limit(^limit)
    |> preload(items: :record)
    |> Repo.all()
  end

  defp apply_order(query, :alphabetical) do
    order_by(query, [rs], fragment("? COLLATE NOCASE ASC", rs.name))
  end

  defp apply_order(query, _) do
    order_by(query, [rs], desc: rs.updated_at)
  end

  @spec get_record_set!(String.t()) :: RecordSet.t()
  def get_record_set!(id) do
    RecordSet
    |> Repo.get!(id)
    |> Repo.preload(items: :record)
  end

  @spec create_record_set(map()) :: {:ok, RecordSet.t()} | {:error, Ecto.Changeset.t()}
  def create_record_set(attrs) do
    %RecordSet{}
    |> RecordSet.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, record_set} -> {:ok, Repo.preload(record_set, items: :record)}
      error -> error
    end
  end

  @spec update_record_set(RecordSet.t(), map()) ::
          {:ok, RecordSet.t()} | {:error, Ecto.Changeset.t()}
  def update_record_set(%RecordSet{} = record_set, attrs) do
    record_set
    |> RecordSet.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, record_set} -> {:ok, Repo.preload(record_set, [items: :record], force: true)}
      error -> error
    end
  end

  @spec delete_record_set(RecordSet.t()) :: {:ok, RecordSet.t()} | {:error, Ecto.Changeset.t()}
  def delete_record_set(%RecordSet{} = record_set) do
    Repo.delete(record_set)
  end

  @spec change_record_set(RecordSet.t(), map()) :: Ecto.Changeset.t()
  def change_record_set(%RecordSet{} = record_set, attrs \\ %{}) do
    RecordSet.changeset(record_set, attrs)
  end

  @spec add_record_to_set(RecordSet.t(), String.t()) ::
          {:ok, RecordSet.t()} | {:error, Ecto.Changeset.t()}
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

  @spec remove_record_from_set(RecordSet.t(), String.t()) :: {:ok, RecordSet.t()}
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

  @spec reorder_records_in_set(RecordSet.t(), [String.t()]) :: {:ok, RecordSet.t()}
  def reorder_records_in_set(%RecordSet{} = record_set, ordered_record_ids)
      when is_list(ordered_record_ids) do
    Repo.transaction(fn ->
      ordered_record_ids
      |> Enum.with_index()
      |> Enum.each(fn {record_id, position} ->
        from(i in RecordSetItem,
          where: i.record_set_id == ^record_set.id and i.record_id == ^record_id
        )
        |> Repo.update_all(set: [position: position])
      end)
    end)

    {:ok, get_record_set!(record_set.id)}
  end

  @spec move_record_in_set(RecordSet.t(), String.t(), :up | :down) :: {:ok, RecordSet.t()}
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

  @spec list_record_sets_for_record(String.t()) :: [RecordSet.t()]
  def list_record_sets_for_record(record_id) do
    from(rs in RecordSet,
      join: i in RecordSetItem,
      on: i.record_set_id == rs.id,
      where: i.record_id == ^record_id,
      order_by: [asc: rs.name],
      preload: [items: :record]
    )
    |> Repo.all()
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
