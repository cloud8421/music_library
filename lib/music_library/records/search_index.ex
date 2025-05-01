defmodule MusicLibrary.Records.SearchIndex do
  @moduledoc """
  The search index is backed by a virtual table that uses
  the [FTS5](https://www.sqlite.org/fts5.html) extension.

  Data in the table is automatically synced via a set of triggers defined in
  `priv/repo/migrations/20241122094655_create_records_search_index.exs`.

  Most of the `records` table columns are replicated for ease of use -
  so that it's not necessary to fetch actual `records` after obtaining search results.
  """
  use Ecto.Schema

  alias MusicLibrary.Records.{Artist, Record}

  @primary_key {:id, :binary_id, autogenerate: false}
  schema "records_search_index" do
    field :type, Ecto.Enum, values: Record.types()
    field :format, Ecto.Enum, values: Record.formats()
    field :title, :string
    field :musicbrainz_id, Ecto.UUID
    field :genres, {:array, :string}
    field :release_date, :string
    field :purchased_at, :utc_datetime
    field :cover_hash, :string
    field :release_ids, {:array, :string}, default: []
    field :included_release_group_ids, {:array, :string}, default: []

    embeds_many :artists, Artist
  end
end
