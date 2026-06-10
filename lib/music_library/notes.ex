defmodule MusicLibrary.Notes do
  @moduledoc """
  Free-text notes attached to records and artists.

  Rows are keyed by `entity` + `musicbrainz_id` (no FK to `records` or
  `artist_infos`). Because they attach to the musical entity rather than a
  database row, notes intentionally survive record deletion and re-import.
  """

  alias MusicLibrary.Notes.Note
  alias MusicLibrary.Repo

  @spec get_note(atom(), String.t()) :: Note.t() | nil
  def get_note(entity, musicbrainz_id) do
    Repo.get_by(Note, entity: entity, musicbrainz_id: musicbrainz_id)
  end

  @spec create_note(Note.t(), map()) :: {:ok, Note.t()} | {:error, Ecto.Changeset.t()}
  def create_note(note, attrs) do
    note
    |> Note.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_note(Note.t(), map()) :: {:ok, Note.t()} | {:error, Ecto.Changeset.t()}
  def update_note(note, attrs) do
    note
    |> Note.changeset(attrs)
    |> Repo.update()
  end

  @spec change_note(Note.t(), map()) :: Ecto.Changeset.t()
  def change_note(note, attrs) do
    Note.changeset(note, attrs)
  end
end
