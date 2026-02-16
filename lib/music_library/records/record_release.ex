defmodule MusicLibrary.Records.RecordRelease do
  use Ecto.Schema

  @primary_key false
  schema "record_releases" do
    field :record_id, :binary_id
    field :release_id, :string
    field :cover_hash, :string
    field :purchased_at, :utc_datetime
  end
end
