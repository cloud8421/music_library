defmodule MusicLibrary.Repo.Migrations.CreateRecordReleases do
  use Ecto.Migration

  def up do
    execute """
    CREATE TABLE record_releases (
      record_id TEXT NOT NULL,
      release_id TEXT NOT NULL,
      cover_hash TEXT,
      purchased_at TEXT,
      PRIMARY KEY (record_id, release_id),
      FOREIGN KEY (record_id) REFERENCES records(id) ON DELETE CASCADE
    );
    """

    execute """
    CREATE INDEX record_releases_release_id_index ON record_releases(release_id);
    """

    flush()

    # Populate from existing data
    execute """
    INSERT INTO record_releases (record_id, release_id, cover_hash, purchased_at)
    SELECT records.id, json_each.value, records.cover_hash, records.purchased_at
    FROM records, json_each(records.release_ids);
    """

    flush()

    # Trigger: after insert on records, expand release_ids into record_releases
    execute """
    CREATE TRIGGER record_releases_after_insert
    AFTER INSERT ON records
    BEGIN
      INSERT INTO record_releases (record_id, release_id, cover_hash, purchased_at)
      SELECT NEW.id, json_each.value, NEW.cover_hash, NEW.purchased_at
      FROM json_each(NEW.release_ids);
    END;
    """

    # Trigger: before update on records, remove old rows
    execute """
    CREATE TRIGGER record_releases_before_update
    BEFORE UPDATE ON records
    BEGIN
      DELETE FROM record_releases WHERE record_id = OLD.id;
    END;
    """

    # Trigger: after update on records, insert new rows
    execute """
    CREATE TRIGGER record_releases_after_update
    AFTER UPDATE ON records
    BEGIN
      INSERT INTO record_releases (record_id, release_id, cover_hash, purchased_at)
      SELECT NEW.id, json_each.value, NEW.cover_hash, NEW.purchased_at
      FROM json_each(NEW.release_ids);
    END;
    """

    # Trigger: before delete on records, remove rows
    execute """
    CREATE TRIGGER record_releases_before_delete
    BEFORE DELETE ON records
    BEGIN
      DELETE FROM record_releases WHERE record_id = OLD.id;
    END;
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS record_releases_after_insert"
    execute "DROP TRIGGER IF EXISTS record_releases_before_update"
    execute "DROP TRIGGER IF EXISTS record_releases_after_update"
    execute "DROP TRIGGER IF EXISTS record_releases_before_delete"
    execute "DROP TABLE IF EXISTS record_releases"
  end
end
