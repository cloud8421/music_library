defmodule MusicLibrary.Repo.Migrations.RemoveRecordsCoverData do
  use Ecto.Migration

  def up do
    alter table(:records) do
      remove(:cover_data)
    end
  end

  def down do
    alter table(:records) do
      add :cover_data, :binary
    end
  end
end
