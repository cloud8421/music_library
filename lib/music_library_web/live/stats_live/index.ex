defmodule MusicLibraryWeb.StatsLive.Index do
  use MusicLibraryWeb, :live_view

  import MusicLibraryWeb.StatsLive.DataComponents

  alias MusicLibrary.{Records, Wishlist}
  alias Records.Record

  def mount(_params, _session, socket) do
    collection_count_by_format = Records.count_records_by_format()

    collection_count_by_type = Records.count_records_by_type()

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

  # The Tailwind build step requires all needed classes to be explicitly referenced
  # in the source code, and not dynamically generated. This implies that one cannot
  # (for example) interpolate a number in a class name.
  defp stats_class(collection) do
    case Enum.count(collection) do
      1 -> "grid-cols-1"
      2 -> "grid-cols-2"
      3 -> "grid-cols-3"
      4 -> "grid-cols-4"
      5 -> "grid-cols-5"
      6 -> "grid-cols-6"
      7 -> "grid-cols-7"
      8 -> "grid-cols-8"
      9 -> "grid-cols-9"
      _other -> ""
    end
  end
end
