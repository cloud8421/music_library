defmodule MusicLibraryWeb.StatsController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Records

  def index(conn, _params) do
    records_count = Records.count_records()
    record = Records.get_latest_record!()
    render(conn, :index, records_count: records_count, record: record, nav_section: :dashboard)
  end
end
