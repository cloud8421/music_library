defmodule MusicLibrary.Repo.Migrations.AddFormatToRecords do
  use Ecto.Migration

  def change do
    alter table(:records) do
      add :format, :string, default: "cd"
    end
  end
end
