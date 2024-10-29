defmodule MusicLibraryWeb.StatsLive.Index do
  use MusicLibraryWeb, :live_view

  alias MusicLibrary.{Records, Wishlist}
  alias Records.Record

  def mount(_params, _session, socket) do
    collection_count_by_format =
      Records.count_records_by_format()
      |> Enum.sort_by(fn {_format, count} -> count end, :desc)

    collection_count_by_type =
      Records.count_records_by_type()
      |> Enum.sort_by(fn {_type, count} -> count end, :desc)

    collection_count =
      Enum.reduce(collection_count_by_format, 0, fn {_, count}, acc -> acc + count end)

    wishlist_count = Wishlist.count()

    latest_record = Records.get_latest_record!()

    {:ok,
     socket
     |> assign(
       page_title: gettext("Stats"),
       collection_count_by_format: collection_count_by_format,
       collection_count_by_type: collection_count_by_type,
       collection_count: collection_count,
       wishlist_count: wishlist_count,
       latest_record: latest_record,
       nav_section: :stats
     )}
  end
end
