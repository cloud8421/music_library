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

  def index(conn, params) do
    limit =
      Map.get(params, "limit", "20")
      |> String.to_integer()

    offset =
      Map.get(params, "offset", "0")
      |> String.to_integer()

    total = Collection.search_records_count("")

    records = Collection.search_records("", limit: limit, offset: offset)

    render(conn, :index, total: total, limit: limit, offset: offset, records: records)
  end
end
