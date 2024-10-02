defmodule MusicLibrary.Repo.Migrations.RemoveYearFromRecords do
  use Ecto.Migration

  def change do
    alter table(:records) do
      remove :year
    end
  end
end
