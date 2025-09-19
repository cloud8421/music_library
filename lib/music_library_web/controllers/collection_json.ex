defmodule MusicLibraryWeb.CollectionJSON do
  use MusicLibraryWeb, :json

  alias MusicLibrary.Assets.Transform

  def show(%{record: record}) do
    record(record)
  end

  def index(%{records: records, total: total, limit: limit, offset: offset}) do
    %{
      total: total,
      limit: limit,
      offset: offset,
      records: Enum.map(records, &record/1)
    }
  end

  defp record(record) do
    %{
      id: record.id,
      artists: Enum.map(record.artists, & &1.name),
      title: record.title,
      cover_url: url(~p"/api/assets/#{Transform.new(hash: record.cover_hash)}"),
      thumb_url: url(~p"/api/assets/#{Transform.new(hash: record.cover_hash, width: 480)}")
    }
  end
end
