defmodule LastFm.Feed do
  @moduledoc """
  Persists scrobbled tracks in `MusicLibrary.Repo` and publishes feed updates.

  Tracks are inserted into the `scrobbled_tracks` table with conflict handling on
  `[:scrobbled_at_uts, :title]` to avoid duplicates, then scrobble rules are applied
  to newly inserted rows.
  """

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

  @spec update([LastFm.Track.t()]) :: {:ok, non_neg_integer()} | no_return
  def update(tracks) do
    track_params =
      tracks
      |> Enum.map(fn t -> Map.take(t, @insertable_fields) end)
      |> Enum.map(&Map.to_list/1)

    {count, tracks} =
      MusicLibrary.Repo.insert_all(LastFm.Track, track_params,
        on_conflict: :nothing,
        conflict_target: [:scrobbled_at_uts, :title],
        returning: true
      )

    tracks
    |> MusicLibrary.ScrobbleRules.apply_all_rules()
    |> MusicLibrary.ScrobbleRules.log_apply_results()

    Phoenix.PubSub.broadcast(LastFm.PubSub, "feed:update", %{track_count: count})

    {:ok, count}
  end

  @spec subscribe() :: :ok
  def subscribe do
    Phoenix.PubSub.subscribe(LastFm.PubSub, "feed:update")
  end
end
