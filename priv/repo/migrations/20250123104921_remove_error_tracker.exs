defmodule MusicLibrary.Repo.Migrations.RemoveErrorTracker do
  use Ecto.Migration

  def change do
    drop table(:error_tracker_meta)
    drop table(:error_tracker_errors)
    drop table(:error_tracker_occurrences)
  end
end
