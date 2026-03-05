defmodule MusicLibrary.Repo.Migrations.AddRecordIdIndexToRecordSetItems do
  use Ecto.Migration

  def change do
    # Speeds up queries filtering by record_id alone (e.g., record deletion cascades, cross-set lookups)
    create index(:record_set_items, [:record_id])
  end
end
