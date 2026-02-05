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

  def changeset(record_set, attrs) do
    record_set
    |> cast(attrs, [:name, :description])
    |> validate_required([:name])
  end
end
