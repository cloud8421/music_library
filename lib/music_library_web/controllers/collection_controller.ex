defmodule MusicLibraryWeb.CollectionController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Collection

  def latest(conn, _params) do
    latest_record = Collection.get_latest_record!()

    render(conn, :show, record: latest_record)
  end
end
