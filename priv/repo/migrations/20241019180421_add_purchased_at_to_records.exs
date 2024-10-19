defmodule MusicLibrary.Repo.Migrations.AddPurchasedAtToRecords do
  use Ecto.Migration

  def change do
    alter table(:records) do
      add :purchased_at, :utc_datetime
    end
  end
end
