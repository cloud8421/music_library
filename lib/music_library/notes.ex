defmodule MusicLibrary.Notes do
  alias MusicLibrary.Notes.Note
  alias MusicLibrary.Repo

  def get_note(entity, musicbrainz_id) do
    Repo.get_by(Note, entity: entity, musicbrainz_id: musicbrainz_id)
  end

  def create_note(note, attrs) do
    note
    |> Note.changeset(attrs)
    |> Repo.insert()
  end

  def update_note(note, attrs) do
    note
    |> Note.changeset(attrs)
    |> Repo.update()
  end

  def change_note(note, attrs) do
    Note.changeset(note, attrs)
  end
end
