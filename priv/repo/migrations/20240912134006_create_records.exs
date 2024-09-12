defmodule MusicLibrary.Repo.Migrations.CreateRecords do
  use Ecto.Migration

  def change do
    create table(:records, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :type, :string
      add :title, :string
      add :musicbrainz_id, :uuid
      add :year, :integer
      add :genres, {:array, :string}
      add :image, :string

      timestamps(type: :utc_datetime)
    end
  end
end
