defmodule MusicLibraryWeb.StatsController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Records

  def index(conn, _params) do
    records_count_by_format =
      Records.count_records_by_format()
      |> Enum.sort_by(fn {_format, count} -> count end, :desc)

    records_count_by_type =
      Records.count_records_by_type()
      |> Enum.sort_by(fn {_type, count} -> count end, :desc)

    records_count = Enum.reduce(records_count_by_format, 0, fn {_, count}, acc -> acc + count end)
    latest_record = Records.get_latest_record!()

    conn
    |> assign(:page_title, gettext("Stats"))
    |> render(:index,
      records_count_by_format: records_count_by_format,
      records_count_by_type: records_count_by_type,
      records_count: records_count,
      latest_record: latest_record,
      nav_section: :stats
    )
  end
end
