defmodule MusicLibraryWeb.CollectionJSON do
  use MusicLibraryWeb, :json

  alias MusicLibrary.Assets.Transform

  @large_cover_width 1000
  @medium_cover_width 400
  @small_cover_width 80

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
      selected_release_id: record.selected_release_id,
      artists: Enum.map(record.artists, & &1.name),
      title: record.title,
      covers: cover_urls(record.cover_hash)
    }
  end

  defp cover_urls(cover_hash) do
    %{
      original: cover_url(cover_hash, nil),
      large: cover_url(cover_hash, @large_cover_width),
      medium: cover_url(cover_hash, @medium_cover_width),
      small: cover_url(cover_hash, @small_cover_width)
    }
  end

  defp cover_url(cover_hash, width) do
    url(~p"/api/v1/assets/#{Transform.new(hash: cover_hash, width: width)}")
  end
end
