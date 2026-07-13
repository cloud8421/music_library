defmodule MusicLibrary.RecordSets do
  @moduledoc """
  User-curated record groupings with ordered items.
  """

  import Ecto.Query, warn: false

  alias Ecto.Changeset
  alias MusicLibrary.Records.Record
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

  @spec create_record_set(map()) :: {:ok, RecordSet.t()} | {:error, Changeset.t()}
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
          {:ok, RecordSet.t()} | {:error, Changeset.t()}
  def update_record_set(%RecordSet{} = record_set, attrs) do
    record_set
    |> RecordSet.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, record_set} -> {:ok, Repo.preload(record_set, [items: :record], force: true)}
      error -> error
    end
  end

  @spec empty_record_set(RecordSet.t()) :: {:ok, RecordSet.t()}
  def empty_record_set(%RecordSet{} = record_set) do
    from(i in RecordSetItem, where: i.record_set_id == ^record_set.id)
    |> Repo.delete_all()

    {:ok, get_record_set!(record_set.id)}
  end

  @spec delete_record_set(RecordSet.t()) :: {:ok, RecordSet.t()} | {:error, Changeset.t()}
  def delete_record_set(%RecordSet{} = record_set) do
    Repo.delete(record_set)
  end

  @spec change_record_set(RecordSet.t(), map()) :: Changeset.t()
  def change_record_set(%RecordSet{} = record_set, attrs \\ %{}) do
    RecordSet.changeset(record_set, attrs)
  end

  @spec add_record_to_set(RecordSet.t(), String.t()) ::
          {:ok, RecordSet.t()} | {:error, Changeset.t() | :record_not_found}
  def add_record_to_set(%RecordSet{} = record_set, record_id) do
    now = truncate_to_second(DateTime.utc_now())

    case do_insert_record_to_sets(record_id, [record_set.id], now) do
      {:ok, 0} ->
        changeset =
          %RecordSetItem{}
          |> RecordSetItem.changeset(%{position: 0})
          |> Changeset.put_change(:record_set_id, record_set.id)
          |> Changeset.put_change(:record_id, record_id)
          |> Changeset.add_error(:record_set_id, "has already been taken")

        {:error, changeset}

      {:error, :record_not_found} ->
        {:error, :record_not_found}

      {:ok, _count} ->
        {:ok, get_record_set!(record_set.id)}
    end
  end

  @doc """
  Adds a record to multiple record sets in a single transactional bulk operation.

  Returns `{:ok, inserted_count}` where `inserted_count` is the number of new
  memberships created. Already-existing memberships are silently skipped.
  Returns an error tuple for empty/malformed input, missing record, or missing sets.
  """
  @spec add_record_to_sets(Record.t(), [String.t()]) ::
          {:ok, non_neg_integer()}
          | {:error, :empty_selection}
          | {:error, {:invalid_set_ids, [term()]}}
          | {:error, :record_not_found}
          | {:error, {:record_sets_not_found, [String.t()]}}
  def add_record_to_sets(%Record{} = record, set_ids) when is_list(set_ids) do
    now = truncate_to_second(DateTime.utc_now())

    case normalize_set_ids(set_ids) do
      {:ok, []} ->
        {:error, :empty_selection}

      {:ok, normalized} ->
        do_insert_record_to_sets(record.id, normalized, now)

      {:error, _invalid} = error ->
        error
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

    recompact_positions(record_set)
  end

  # sobelow_skip ["SQL.Query"]
  @spec reorder_records_in_set(RecordSet.t(), [String.t()]) :: {:ok, RecordSet.t()}
  def reorder_records_in_set(%RecordSet{} = record_set, ordered_record_ids)
      when is_list(ordered_record_ids) do
    {case_clauses, params} =
      ordered_record_ids
      |> Enum.with_index()
      |> Enum.reduce({"", []}, fn {record_id, position}, {sql_acc, params_acc} ->
        {"#{sql_acc}WHEN record_id = ? THEN ? ", params_acc ++ [record_id, position]}
      end)

    sql = """
    UPDATE record_set_items
    SET position = CASE #{case_clauses}ELSE position END
    WHERE record_set_id = ?
    """

    Repo.query(sql, params ++ [record_set.id])

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

    case Enum.find_index(items, fn i -> i.record_id == record_id end) do
      nil ->
        :ok

      index ->
        swap_index =
          case direction do
            :up -> index - 1
            :down -> index + 1
          end

        if swap_index >= 0 and swap_index < length(items) do
          item_a = Enum.at(items, index)
          item_b = Enum.at(items, swap_index)

          Repo.transaction(fn ->
            item_a
            |> Changeset.change(position: item_b.position)
            |> Repo.update!()

            item_b
            |> Changeset.change(position: item_a.position)
            |> Repo.update!()
          end)
        end
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

  @doc """
  Returns lightweight set choices for picker rendering and the IDs of sets
  the record already belongs to.

  Returns `{choices, member_set_ids}` where `choices` is a list of maps with
  `:id` and `:name` keys, and `member_set_ids` is a `MapSet` of IDs.
  """
  @spec list_record_set_choices_for_record(String.t()) ::
          {[%{id: String.t(), name: String.t()}], MapSet.t()}
  def list_record_set_choices_for_record(record_id) do
    choices =
      from(rs in RecordSet,
        order_by: [fragment("? COLLATE NOCASE", rs.name), asc: rs.name, asc: rs.id],
        select: %{id: rs.id, name: rs.name}
      )
      |> Repo.all()

    member_set_ids =
      from(i in RecordSetItem,
        where: i.record_id == ^record_id,
        select: i.record_set_id
      )
      |> Repo.all()
      |> MapSet.new()

    {choices, member_set_ids}
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

  defp truncate_to_second(dt), do: %{dt | microsecond: {0, 0}}

  defp recompact_positions(record_set) do
    record_set_id = record_set.id

    record_ids =
      from(i in RecordSetItem,
        where: i.record_set_id == ^record_set_id,
        order_by: [asc: i.position],
        select: i.record_id
      )
      |> Repo.all()

    reorder_records_in_set(record_set, record_ids)
  end

  # Shared immediate-transaction insert path for both single and bulk add APIs.
  # Verifies record existence, fetches selected-set max positions, and bulk-inserts
  # rows with on_conflict: :nothing for idempotency.
  defp do_insert_record_to_sets(record_id, set_ids, now) do
    Repo.transaction(
      fn ->
        unless record_exists?(record_id) do
          Repo.rollback(:record_not_found)
        end

        sets_with_max =
          from(rs in RecordSet,
            where: rs.id in ^set_ids,
            select: %{
              id: rs.id,
              max_position:
                fragment(
                  "(SELECT coalesce(max(i.position), -1) FROM record_set_items AS i WHERE i.record_set_id = ?)",
                  rs.id
                )
            }
          )
          |> Repo.all()

        found_ids = MapSet.new(Enum.map(sets_with_max, & &1.id))

        missing =
          Enum.reject(set_ids, fn set_id ->
            MapSet.member?(found_ids, set_id)
          end)

        if missing != [] do
          Repo.rollback({:record_sets_not_found, missing})
        end

        rows =
          Enum.map(sets_with_max, fn %{id: set_id, max_position: max_pos} ->
            %{
              id: Ecto.UUID.generate(),
              record_set_id: set_id,
              record_id: record_id,
              position: max_pos + 1,
              inserted_at: now,
              updated_at: now
            }
          end)

        {inserted_count, _} =
          Repo.insert_all(
            RecordSetItem,
            rows,
            on_conflict: :nothing,
            conflict_target: [:record_set_id, :record_id]
          )

        inserted_count
      end,
      mode: :immediate
    )
    |> case do
      {:ok, count} -> {:ok, count}
      {:error, :record_not_found} -> {:error, :record_not_found}
      {:error, {:record_sets_not_found, missing}} -> {:error, {:record_sets_not_found, missing}}
    end
  end

  defp record_exists?(record_id) do
    from(r in Record, where: r.id == ^record_id, select: 1)
    |> Repo.exists?()
  end

  # Normalizes and validates a list of set IDs, rejecting malformed values.
  defp normalize_set_ids(set_ids) when is_list(set_ids) do
    result =
      Enum.reduce_while(set_ids, {MapSet.new(), []}, fn raw_id, {seen, invalid} ->
        case Ecto.UUID.cast(raw_id) do
          :error ->
            {:halt, {seen, invalid ++ [raw_id]}}

          {:ok, uuid} ->
            {:cont, {MapSet.put(seen, uuid), invalid}}
        end
      end)

    case result do
      {_seen, [_ | _] = invalid} ->
        {:error, {:invalid_set_ids, invalid}}

      {seen, []} ->
        {:ok, MapSet.to_list(seen)}
    end
  end
end
