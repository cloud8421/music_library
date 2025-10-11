defmodule MusicLibrary.Repo.Migrations.CreateRecordEmbeddings do
  use Ecto.Migration

  def up do
    execute("""
    CREATE TABLE record_embeddings (
      id TEXT PRIMARY KEY,
      record_id TEXT NOT NULL CONSTRAINT record_embeddings_record_id_fkey REFERENCES records(id) ON DELETE CASCADE,
      embedding float[1536] NOT NULL,
      text_representation TEXT NOT NULL,
      inserted_at TEXT NOT NULL,
      updated_at TEXT NOT NULL);
    """)

    execute("""
    CREATE UNIQUE INDEX record_embeddings_record_id_index ON record_embeddings (record_id);
    """)
  end

  def down do
    drop table(:record_embeddings)
  end
end
