defmodule MusicLibraryWeb.StatsController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Records

  def index(conn, _params) do
    records_count_by_format = Records.count_records_by_format()
    records_count = Enum.reduce(records_count_by_format, 0, fn {_, count}, acc -> acc + count end)
    latest_record = Records.get_latest_record!()

    render(conn, :index,
      records_count_by_format: records_count_by_format,
      records_count: records_count,
      latest_record: latest_record,
      nav_section: :dashboard
    )
  end
end
