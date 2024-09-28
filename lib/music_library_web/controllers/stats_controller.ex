defmodule MusicLibraryWeb.StatsController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Records

  def index(conn, _params) do
    records_count = Records.count_records()
    render(conn, :index, records_count: records_count)
  end
end
