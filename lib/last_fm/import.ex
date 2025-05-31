defmodule LastFm.Import do
  def batch(opts) do
    with {:ok, tracks} <- LastFm.get_tracks(opts) do
      LastFm.Feed.update(tracks)
    end
  end
end
