defmodule MusicLibrary.Repo.Migrations.AddIndexToRecords do
  use Ecto.Migration

  def change do
    create index("records", [:format])
    create index("records", [:title])
    create index("records", [:musicbrainz_id])
  end
end
