defmodule MusicLibrary.Records do
  import Ecto.Query, warn: false
  alias MusicLibrary.Repo

  alias MusicLibrary.Records.Record

  def list_records do
    q =
      from r in Record,
        order_by: r.artists[0]["sort_name"],
        limit: 50

    Repo.all(q)
  end

  def get_record!(id), do: Repo.get!(Record, id)

  def get_image!(id) do
    q =
      from r in Record,
        where: r.id == ^id,
        select: r.image_data

    Repo.one!(q)
  end

  def create_record(attrs \\ %{}) do
    %Record{}
    |> Record.changeset(attrs)
    |> Repo.insert()
  end

  def update_record(%Record{} = record, attrs) do
    record
    |> Record.changeset(attrs)
    |> Repo.update()
  end

  def delete_record(%Record{} = record) do
    Repo.delete(record)
  end

  def change_record(%Record{} = record, attrs \\ %{}) do
    Record.changeset(record, attrs)
  end
end
