defmodule MusicLibrary.Repo.Migrations.AddReleaseToRecords do
  use Ecto.Migration
  import Ecto.Query

  def up do
    alter table(:records) do
      add :release, :string
    end

    flush()

    query =
      from(r in MusicLibrary.Records.Record,
        update: [set: [release: r.year]]
      )

    MusicLibrary.Repo.update_all(query, [])
  end

  def down do
    alter table(:records) do
      remove :release
    end
  end
end
