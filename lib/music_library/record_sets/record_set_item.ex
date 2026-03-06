defmodule MusicLibrary.RecordSets.RecordSetItem do
  use Ecto.Schema

  import Ecto.Changeset

  alias MusicLibrary.Records.Record
  alias MusicLibrary.RecordSets.RecordSet

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "record_set_items" do
    field :position, :integer

    belongs_to :record_set, RecordSet
    belongs_to :record, Record

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(record_set_item, attrs) do
    record_set_item
    |> cast(attrs, [:position])
    |> validate_required([:position])
  end
end
