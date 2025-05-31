defmodule LastFm.Import do
  @insertable_fields [
    :musicbrainz_id,
    :title,
    :artist,
    :album,
    :cover_url,
    :scrobbled_at_uts,
    :scrobbled_at_label,
    :last_fm_data
  ]

  def batch(opts) do
    with {:ok, tracks} <- LastFm.get_tracks(opts) do
      track_params =
        tracks
        |> Enum.map(fn t -> Map.take(t, @insertable_fields) end)
        |> Enum.map(&Map.to_list/1)

      MusicLibrary.Repo.insert_all(LastFm.Track, track_params)
    end
  end
end
