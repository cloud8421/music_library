defmodule MusicLibraryWeb.CollectionJSON do
  use MusicLibraryWeb, :json

  def show(%{record: record}) do
    %{
      artists: Enum.map(record.artists, & &1.name),
      title: record.title,
      cover_url: url(~p"/api/covers/#{record.id}?#{[vsn: record.cover_hash]}")
    }
  end
end
