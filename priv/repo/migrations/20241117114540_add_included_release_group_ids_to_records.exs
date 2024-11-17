defmodule MusicLibrary.Repo.Migrations.AddIncludedReleaseGroupIdsToRecords do
  use Ecto.Migration

  def change do
    alter table(:records) do
      add :included_release_group_ids, {:array, :string}, default: []
    end

    create index(:records, [:included_release_group_ids])
  end
end
