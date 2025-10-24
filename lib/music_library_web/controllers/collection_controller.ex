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

  def on_this_day(conn, params) do
    current_date =
      case Map.get(params, "date") do
        nil -> Date.utc_today()
        date_string -> Date.from_iso8601!(date_string)
      end

    records_on_this_day = Collection.get_records_on_this_day(current_date)

    render(conn, :on_this_day, records: records_on_this_day)
  end

  def index(conn, params) do
    limit =
      params
      |> Map.get("limit", "20")
      |> String.to_integer()

    offset =
      params
      |> Map.get("offset", "0")
      |> String.to_integer()

    total = Collection.search_records_count("")

    records = Collection.search_records("", limit: limit, offset: offset)

    render(conn, :index, total: total, limit: limit, offset: offset, records: records)
  end
end
