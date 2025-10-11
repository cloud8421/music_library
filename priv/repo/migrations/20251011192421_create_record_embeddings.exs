defmodule MusicLibrary.Repo.Migrations.CreateRecordEmbeddings do
  use Ecto.Migration

  def change do
    create table(:record_embeddings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :record_id, references(:records, type: :binary_id, on_delete: :delete_all), null: false

      add :embedding, :text, null: false
      add :text_representation, :text, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:record_embeddings, [:record_id])
  end
end
