defmodule MusicLibrary.Repo.Migrations.AddRecordsReleaseDateIndex do
  use Ecto.Migration

  def change do
    # Supports ORDER BY release_date DESC (collection, wishlist, search results)
    # and strftime filtering in Collection.get_records_on_this_day/1
    create index(:records, [:release_date])
  end
end
