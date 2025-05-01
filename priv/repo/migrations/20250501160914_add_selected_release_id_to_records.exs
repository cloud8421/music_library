defmodule MusicLibrary.Repo.Migrations.AddSelectedReleaseIdToRecords do
  use Ecto.Migration

  def change do
    alter table(:records) do
      add :selected_release_id, :string
    end
  end
end
