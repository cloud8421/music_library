defmodule LastFm.Import do
  @spec batch(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def batch(opts) do
    with {:ok, tracks} <- LastFm.get_tracks(opts) do
      LastFm.Feed.update(tracks)
    end
  end
end
