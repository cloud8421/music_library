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

  def on_this_day(%{records: records}) do
    %{
      records: Enum.map(records, &record/1)
    }
  end

  defp record(record) do
    %{
      id: record.id,
      type: record.type,
      format: record.format,
      musicbrainz_id: record.musicbrainz_id,
      genres: record.genres,
      release_date: record.release_date,
      purchased_at: record.purchased_at,
      artists: Enum.map(record.artists, & &1.name),
      title: record.title,
      cover_url: url(~p"/api/v1/assets/#{Transform.new(hash: record.cover_hash)}"),
      thumb_url: url(~p"/api/v1/assets/#{Transform.new(hash: record.cover_hash, width: 480)}"),
      mini_cover_url:
        url(~p"/api/v1/assets/#{Transform.new(hash: record.cover_hash, width: 150)}"),
      micro_cover_url:
        url(~p"/api/v1/assets/#{Transform.new(hash: record.cover_hash, width: 40)}")
    }
  end
end
