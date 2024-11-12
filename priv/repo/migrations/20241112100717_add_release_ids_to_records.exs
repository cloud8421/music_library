defmodule MusicLibrary.Repo.Migrations.AddReleaseIdsToRecords do
  use Ecto.Migration

  def change do
    alter table(:records) do
      add :release_ids, {:array, :string}, default: []
    end

    create index(:records, [:release_ids])
  end
end
