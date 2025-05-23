defmodule MusicLibrary.Records.ArtistRecord do
  @moduledoc """
  This is a lookup table that maps from an artist musicbrainz_id to a record id.
  """
  use Ecto.Schema

  alias MusicLibrary.Artists.Artist

  @primary_key false
  schema "artist_records" do
    field :musicbrainz_id, Ecto.UUID
    field :record_id, Ecto.UUID

    embeds_one :artist, Artist
  end
end
