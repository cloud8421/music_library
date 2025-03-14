defmodule LastFm.Feed do
  @moduledoc """
  Holds a in-memory cache of scrobbled tracks.

  Tracks are keyed and ASC ordered by their scrobbling unix timestamp. While this
  is technically prone to collision, it's very unlikely for that to happen due to the
  nature of the data.
  """

  @spec create_table!() :: :ok | no_return
  def create_table! do
    __MODULE__ = :ets.new(__MODULE__, [:ordered_set, :named_table, :public])
    :ok
  end

  @spec update([LastFm.Track.t()]) :: :ok | no_return
  def update(tracks) do
    data = Enum.map(tracks, fn t -> {t.scrobbled_at_uts, t} end)

    :ets.delete_all_objects(__MODULE__)
    :ets.insert(__MODULE__, data)

    Phoenix.PubSub.broadcast(LastFm.PubSub, "feed:update", %{tracks: tracks})
  end

  @spec all_tracks() :: [LastFm.Track.t()]
  def all_tracks do
    m = [
      {
        {:_, :_},
        [],
        [{:element, 2, :"$_"}]
      }
    ]

    # reversing to get tracks in DESC order
    :ets.select_reverse(__MODULE__, m)
  end

  @spec subscribe() :: :ok
  def subscribe do
    Phoenix.PubSub.subscribe(LastFm.PubSub, "feed:update")
  end
end
