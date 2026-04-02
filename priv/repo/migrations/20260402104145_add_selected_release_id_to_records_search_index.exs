defmodule MusicLibrary.Repo.Migrations.AddSelectedReleaseIdToRecordsSearchIndex do
  use Ecto.Migration

  def up do
    execute "DROP TRIGGER IF EXISTS records_after_update"
    execute "DROP TRIGGER IF EXISTS records_after_insert"
    execute "DROP TABLE records_search_index"

    flush()

    execute """
    CREATE VIRTUAL TABLE records_search_index USING fts5(
      id UNINDEXED,
      type,
      format,
      title,
      normalized_title,
      artists,
      normalized_artists,
      genres,
      musicbrainz_id,
      release_ids UNINDEXED,
      included_release_group_ids UNINDEXED,
      selected_release_id UNINDEXED,
      cover_hash UNINDEXED,
      purchased_at UNINDEXED,
      release_date,
      inserted_at UNINDEXED,
      updated_at UNINDEXED
    );
    """

    flush()

    execute """
    CREATE TRIGGER records_after_insert
    AFTER INSERT ON records
    BEGIN
      INSERT INTO records_search_index(
        id,
        type,
        format,
        title,
        normalized_title,
        artists,
        normalized_artists,
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        selected_release_id,
        cover_hash,
        purchased_at,
        release_date,
        inserted_at,
        updated_at
      ) SELECT
        id,
        type,
        format,
        title,
        unaccent(title),
        artists,
        unaccent(artists),
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        selected_release_id,
        cover_hash,
        purchased_at,
        release_date,
        inserted_at,
        updated_at
      FROM records
      WHERE NEW.id = records.id;
    END;
    """

    execute """
    CREATE TRIGGER records_after_update
    AFTER UPDATE ON records
    BEGIN
      INSERT INTO records_search_index(
        id,
        type,
        format,
        title,
        normalized_title,
        artists,
        normalized_artists,
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        selected_release_id,
        cover_hash,
        purchased_at,
        release_date,
        inserted_at,
        updated_at
      ) SELECT
        id,
        type,
        format,
        title,
        unaccent(title),
        artists,
        unaccent(artists),
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        selected_release_id,
        cover_hash,
        purchased_at,
        release_date,
        inserted_at,
        updated_at
      FROM records
      WHERE NEW.id = records.id;
    END;
    """

    flush()

    execute """
    INSERT INTO records_search_index(
      id,
      type,
      format,
      title,
      normalized_title,
      artists,
      normalized_artists,
      genres,
      musicbrainz_id,
      release_ids,
      included_release_group_ids,
      selected_release_id,
      cover_hash,
      purchased_at,
      release_date,
      inserted_at,
      updated_at
    ) SELECT
      id,
      type,
      format,
      title,
      unaccent(title),
      artists,
      unaccent(artists),
      genres,
      musicbrainz_id,
      release_ids,
      included_release_group_ids,
      selected_release_id,
      cover_hash,
      purchased_at,
      release_date,
      inserted_at,
      updated_at
    FROM records;
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS records_after_update"
    execute "DROP TRIGGER IF EXISTS records_after_insert"
    execute "DROP TABLE records_search_index"

    flush()

    execute """
    CREATE VIRTUAL TABLE records_search_index USING fts5(
      id UNINDEXED,
      type,
      format,
      title,
      normalized_title,
      artists,
      normalized_artists,
      genres,
      musicbrainz_id,
      release_ids UNINDEXED,
      included_release_group_ids UNINDEXED,
      cover_hash UNINDEXED,
      purchased_at UNINDEXED,
      release_date,
      inserted_at UNINDEXED,
      updated_at UNINDEXED
    );
    """

    flush()

    execute """
    CREATE TRIGGER records_after_insert
    AFTER INSERT ON records
    BEGIN
      INSERT INTO records_search_index(
        id,
        type,
        format,
        title,
        normalized_title,
        artists,
        normalized_artists,
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        cover_hash,
        purchased_at,
        release_date,
        inserted_at,
        updated_at
      ) SELECT
        id,
        type,
        format,
        title,
        unaccent(title),
        artists,
        unaccent(artists),
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        cover_hash,
        purchased_at,
        release_date,
        inserted_at,
        updated_at
      FROM records
      WHERE NEW.id = records.id;
    END;
    """

    execute """
    CREATE TRIGGER records_after_update
    AFTER UPDATE ON records
    BEGIN
      INSERT INTO records_search_index(
        id,
        type,
        format,
        title,
        normalized_title,
        artists,
        normalized_artists,
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        cover_hash,
        purchased_at,
        release_date,
        inserted_at,
        updated_at
      ) SELECT
        id,
        type,
        format,
        title,
        unaccent(title),
        artists,
        unaccent(artists),
        genres,
        musicbrainz_id,
        release_ids,
        included_release_group_ids,
        cover_hash,
        purchased_at,
        release_date,
        inserted_at,
        updated_at
      FROM records
      WHERE NEW.id = records.id;
    END;
    """

    flush()

    execute """
    INSERT INTO records_search_index(
      id,
      type,
      format,
      title,
      normalized_title,
      artists,
      normalized_artists,
      genres,
      musicbrainz_id,
      release_ids,
      included_release_group_ids,
      cover_hash,
      purchased_at,
      release_date,
      inserted_at,
      updated_at
    ) SELECT
      id,
      type,
      format,
      title,
      unaccent(title),
      artists,
      unaccent(artists),
      genres,
      musicbrainz_id,
      release_ids,
      included_release_group_ids,
      cover_hash,
      purchased_at,
      release_date,
      inserted_at,
      updated_at
    FROM records;
    """
  end
end
