defmodule MusicLibrary.Records.SearchIndex do
  use Ecto.Schema

  @formats [:cd, :vinyl, :blu_ray, :dvd, :multi]
  @types [:album, :ep, :live, :compilation, :single, :other]

  # q = from s in MusicLibrary.Records.SearchIndex,
  # where: fragment("records_index = 'lex*'"), select: s.id

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "records_search_index" do
    field :type, Ecto.Enum, values: @types
    field :format, Ecto.Enum, values: @formats
    field :title, :string
    field :musicbrainz_id, Ecto.UUID
    field :genres, {:array, :string}
    field :release, :string
    field :purchased_at, :utc_datetime
    field :cover_hash, :string
    field :release_ids, {:array, :string}, default: []
    field :included_release_group_ids, {:array, :string}, default: []

    embeds_many :artists, Artist do
      field :name, :string
      field :sort_name, :string
      field :disambiguation, :string
      field :musicbrainz_id, Ecto.UUID
    end
  end
end
