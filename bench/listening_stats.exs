alias MusicLibrary.ListeningStats

Logger.configure(level: :error)

timezone = MusicLibrary.default_timezone()

Benchee.run(
  %{
    "get_top_albums(limit: 10)" => fn -> ListeningStats.get_top_albums(limit: 10) end,
    "get_top_albums_by_days(7)" =>
      fn -> ListeningStats.get_top_albums_by_days(7, limit: 10, timezone: timezone) end,
    "get_top_albums_by_days(30)" =>
      fn -> ListeningStats.get_top_albums_by_days(30, limit: 10, timezone: timezone) end,
    "get_top_albums_by_days(365)" =>
      fn -> ListeningStats.get_top_albums_by_days(365, limit: 10, timezone: timezone) end,
    "get_top_artists(limit: 10)" => fn -> ListeningStats.get_top_artists(limit: 10) end,
    "get_top_artists_by_days(7)" =>
      fn -> ListeningStats.get_top_artists_by_days(7, limit: 10, timezone: timezone) end,
    "get_top_artists_by_days(30)" =>
      fn -> ListeningStats.get_top_artists_by_days(30, limit: 10, timezone: timezone) end,
    "get_top_artists_by_days(365)" =>
      fn -> ListeningStats.get_top_artists_by_days(365, limit: 10, timezone: timezone) end,
    "recent_activity(tz, 100)" => fn -> ListeningStats.recent_activity(timezone, 100) end,
    "list_tracks(page: 1, page_size: 200)" =>
      fn -> ListeningStats.list_tracks(%{page: 1, page_size: 200}) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)
