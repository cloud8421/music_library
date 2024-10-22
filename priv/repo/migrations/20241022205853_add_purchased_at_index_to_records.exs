defmodule MusicLibrary.Repo.Migrations.AddPurchasedAtIndexToRecords do
  use Ecto.Migration

  def change do
    create index("records", [:purchased_at])
  end
end
