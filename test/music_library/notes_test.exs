defmodule MusicLibrary.NotesTest do
  use MusicLibrary.DataCase

  alias MusicLibrary.Notes
  alias MusicLibrary.Notes.Note

  @musicbrainz_id Ecto.UUID.generate()

  describe "get_note/2" do
    test "returns nil when no note exists" do
      assert Notes.get_note(:record, Ecto.UUID.generate()) == nil
    end

    test "returns note for record" do
      {:ok, note} =
        Notes.create_note(%Note{}, %{
          entity: :record,
          musicbrainz_id: @musicbrainz_id,
          content: "Great album"
        })

      found = Notes.get_note(:record, @musicbrainz_id)
      assert found.id == note.id
      assert found.content == "Great album"
    end
  end

  describe "create_note/2" do
    test "creates a note" do
      assert {:ok, note} =
               Notes.create_note(%Note{}, %{
                 entity: :artist,
                 musicbrainz_id: @musicbrainz_id,
                 content: "Fantastic artist"
               })

      assert note.entity == :artist
      assert note.content == "Fantastic artist"
      assert note.musicbrainz_id == @musicbrainz_id
    end
  end

  describe "update_note/2" do
    test "updates note content" do
      {:ok, note} =
        Notes.create_note(%Note{}, %{
          entity: :record,
          musicbrainz_id: @musicbrainz_id,
          content: "Original"
        })

      assert {:ok, updated} = Notes.update_note(note, %{content: "Updated content"})
      assert updated.content == "Updated content"
    end
  end
end
