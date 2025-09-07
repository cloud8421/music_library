defmodule MusicLibrary.Repo.Migrations.RemoveRecordNotes do
  use Ecto.Migration

  def up do
    alter table(:records) do
      remove(:notes)
    end
  end

  def down do
    alter table(:records) do
      add :notes, :string
    end
  end
end
