defmodule LastFm.Import do
  @moduledoc false

  @spec batch(keyword()) :: {:ok, non_neg_integer()} | {:error, term()}
  def batch(opts) do
    with {:ok, tracks} <- LastFm.get_tracks(opts) do
      MusicLibrary.ListeningStats.update(tracks)
    end
  end
end
