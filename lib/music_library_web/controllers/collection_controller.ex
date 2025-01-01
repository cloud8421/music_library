defmodule MusicLibraryWeb.CollectionController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Collection

  def latest(conn, _params) do
    latest_record = Collection.get_latest_record!()

    render(conn, :show, record: latest_record)
  end

  def random(conn, _params) do
    random_record = Collection.get_random_record!()

    render(conn, :show, record: random_record)
  end
end
