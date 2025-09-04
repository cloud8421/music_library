defmodule MusicLibrary.Repo.Migrations.AddNotesToRecords do
  use Ecto.Migration

  def change do
    alter table(:records) do
      add :notes, :string
    end
  end
end
