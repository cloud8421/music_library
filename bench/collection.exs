alias MusicLibrary.Collection

Logger.configure(level: :error)

Benchee.run(
  %{
    "count_records_by_artist(limit: 20)" => fn -> Collection.count_records_by_artist(limit: 20) end,
    "count_records_by_genre(limit: 20)" => fn -> Collection.count_records_by_genre(limit: 20) end,
    "count_records_by_release_year(limit: 20)" => fn -> Collection.count_records_by_release_year(limit: 20) end
  },
  warmup: 2,
  time: 5,
  memory_time: 2
)
