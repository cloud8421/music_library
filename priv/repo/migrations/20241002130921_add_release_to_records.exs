defmodule MusicLibrary.Repo.Migrations.AddReleaseToRecords do
  use Ecto.Migration

  def up do
    alter table(:records) do
      add :release, :string
    end

    flush()

    execute """
    UPDATE records SET release = year;
    """
  end

  def down do
    alter table(:records) do
      remove :release
    end
  end
end
