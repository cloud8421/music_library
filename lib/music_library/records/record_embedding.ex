defmodule MusicLibrary.Records.RecordEmbedding do
  use Ecto.Schema

  import Ecto.Changeset

  alias MusicLibrary.Records.Record

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "record_embeddings" do
    belongs_to :record, Record

    field :embedding, SqliteVec.Ecto.Float32
    field :text_representation, :string

    timestamps(type: :utc_datetime)
  end

  @type t :: %__MODULE__{}

  @spec changeset(t() | Ecto.Changeset.t(), map()) :: Ecto.Changeset.t()
  def changeset(record_embedding, attrs) do
    record_embedding
    |> cast(attrs, [:record_id, :embedding, :text_representation])
    |> validate_required([:record_id, :embedding, :text_representation])
    |> unique_constraint(:record_id)
  end
end
