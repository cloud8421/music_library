defmodule MusicLibraryWeb.CollectionJSON do
  def show(%{record: record}) do
    Map.take(record, [:title])
  end
end
