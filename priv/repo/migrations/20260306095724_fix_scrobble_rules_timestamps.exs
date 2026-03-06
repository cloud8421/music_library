defmodule MusicLibrary.Repo.Migrations.FixScrobbleRulesTimestamps do
  use Ecto.Migration

  def up do
    execute "UPDATE scrobble_rules SET inserted_at = inserted_at || 'Z' WHERE inserted_at NOT LIKE '%Z'"

    execute "UPDATE scrobble_rules SET updated_at = updated_at || 'Z' WHERE updated_at NOT LIKE '%Z'"
  end

  def down do
    execute "UPDATE scrobble_rules SET inserted_at = REPLACE(inserted_at, 'Z', '') WHERE inserted_at LIKE '%Z'"

    execute "UPDATE scrobble_rules SET updated_at = REPLACE(updated_at, 'Z', '') WHERE updated_at LIKE '%Z'"
  end
end
