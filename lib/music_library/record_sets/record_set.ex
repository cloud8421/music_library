defmodule MusicLibrary.RecordSets.RecordSet do
  use Ecto.Schema

  import Ecto.Changeset

  alias MusicLibrary.RecordSets.RecordSetItem

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "record_sets" do
    field :name, :string
    field :description, :string

    has_many :items, RecordSetItem, preload_order: [asc: :position]

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(record_set, attrs) do
    record_set
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_length(:description, max: 10_000)
  end

  @spec count_by_status(t()) :: %{
          collected: non_neg_integer(),
          wishlisted: non_neg_integer(),
          total: non_neg_integer()
        }
  def count_by_status(record_set) do
    record_set.items
    |> Enum.frequencies_by(fn item ->
      if item.record.purchased_at, do: :collected, else: :wishlisted
    end)
    |> Map.new()
    |> Map.put_new(:collected, 0)
    |> Map.put_new(:wishlisted, 0)
    |> Map.put(:total, Enum.count(record_set.items))
  end
end
