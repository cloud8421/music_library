defmodule MusicLibrary.Records.ArtistRecord do
  @moduledoc """
  This is a lookup table that maps from an artist musicbrainz_id to a record id.
  """
  use Ecto.Schema

  alias MusicLibrary.Artists.Artist
  alias MusicLibrary.Notes.Note

  @primary_key false
  schema "artist_records" do
    field :musicbrainz_id, Ecto.UUID
    field :record_id, Ecto.UUID

    has_one :note, Note, foreign_key: :musicbrainz_id, references: :musicbrainz_id

    embeds_one :artist, Artist
  end

  @type t :: %__MODULE__{}
end
