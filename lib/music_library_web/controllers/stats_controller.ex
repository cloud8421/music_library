defmodule MusicLibraryWeb.StatsController do
  use MusicLibraryWeb, :controller

  alias MusicLibrary.Records

  def index(conn, _params) do
    collection_count_by_format =
      Records.count_records_by_format()
      |> Enum.sort_by(fn {_format, count} -> count end, :desc)

    collection_count_by_type =
      Records.count_records_by_type()
      |> Enum.sort_by(fn {_type, count} -> count end, :desc)

    collection_count =
      Enum.reduce(collection_count_by_format, 0, fn {_, count}, acc -> acc + count end)

    latest_record = Records.get_latest_record!()

    conn
    |> assign(:page_title, gettext("Stats"))
    |> render(:index,
      collection_count_by_format: collection_count_by_format,
      collection_count_by_type: collection_count_by_type,
      collection_count: collection_count,
      latest_record: latest_record,
      nav_section: :stats
    )
  end
end
