defmodule LastFm.Feed do
  @moduledoc """
  Holds a in-memory cache of scrobbled tracks.

  Tracks are keyed and ASC ordered by their scrobbling unix timestamp. While this
  is technically prone to collision, it's very unlikely for that to happen since
  scrobbles are sequential events that occur over time - a user can likely only listen
  to one track at a time, and the timestamp has second-level precision.
  """

  import Ecto.Query

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

  @spec update([LastFm.Track.t()]) :: :ok | no_return
  def update(tracks) do
    track_params =
      tracks
      |> Enum.map(fn t -> Map.take(t, @insertable_fields) end)
      |> Enum.map(&Map.to_list/1)

    {count, nil} =
      MusicLibrary.Repo.insert_all(LastFm.Track, track_params,
        on_conflict: :nothing,
        conflict_target: [:scrobbled_at_uts, :title]
      )

    Phoenix.PubSub.broadcast(LastFm.PubSub, "feed:update", %{track_count: count})
  end

  @spec all_tracks(non_neg_integer()) :: [LastFm.Track.t()]
  def all_tracks(limit) do
    q =
      from t in LastFm.Track,
        order_by: {:desc, t.scrobbled_at_uts},
        limit: ^limit

    MusicLibrary.Repo.all(q)
  end

  @spec subscribe() :: :ok
  def subscribe do
    Phoenix.PubSub.subscribe(LastFm.PubSub, "feed:update")
  end
end
