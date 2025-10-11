defmodule MusicLibrary.Records.RecordEmbedding do
  use Ecto.Schema

  import Ecto.Changeset

  alias MusicLibrary.Records.Record

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "record_embeddings" do
    belongs_to :record, Record

    field :embedding, MusicLibrary.Records.RecordEmbedding.EmbeddingType
    field :text_representation, :string

    timestamps(type: :utc_datetime)
  end

  def changeset(record_embedding, attrs) do
    record_embedding
    |> cast(attrs, [:record_id, :embedding, :text_representation])
    |> validate_required([:record_id, :embedding, :text_representation])
    |> validate_embedding_dimensions()
    |> unique_constraint(:record_id)
  end

  defp validate_embedding_dimensions(changeset) do
    case get_change(changeset, :embedding) do
      nil ->
        changeset

      embedding when is_list(embedding) ->
        if length(embedding) == 1536 do
          changeset
        else
          add_error(
            changeset,
            :embedding,
            "must have exactly 1536 dimensions, got #{length(embedding)}"
          )
        end

      _ ->
        add_error(changeset, :embedding, "must be a list of floats")
    end
  end
end
