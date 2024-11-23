defmodule MusicLibrary.Repo.Migrations.AddTypeIndexToRecords do
  use Ecto.Migration

  def change do
    create index("records", [:type])
  end
end
