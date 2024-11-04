defmodule LastFm.Feed do
  @moduledoc """
  Holds a in-memory cache of scrobbled tracks.

  Tracks are keyed and ASC ordered by their scrobbling unix timestamp. While this
  is technically prone to collision, it's very unlikely for that to happen due to the
  nature of the data.
  """
  def create_table! do
    __MODULE__ = :ets.new(__MODULE__, [:ordered_set, :named_table, :public])
    :ok
  end

  def update(tracks) do
    data = Enum.map(tracks, fn t -> {t.scrobbled_at_uts, t} end)

    :ets.delete_all_objects(__MODULE__)
    :ets.insert(__MODULE__, data)

    Phoenix.PubSub.broadcast(LastFm.PubSub, "feed:update", %{tracks: data})
  end

  def all do
    :ets.tab2list(__MODULE__)
    |> Enum.reverse()
  end

  def subscribe do
    Phoenix.PubSub.subscribe(LastFm.PubSub, "feed:update")
  end
end
