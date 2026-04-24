defmodule MusicLibrary.Worker.ArtistRefreshDiscogsData do
  @moduledoc false

  use Oban.Worker, queue: :discogs, max_attempts: 3

  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_info_id}}) do
    artist_info_id
    |> MusicLibrary.Artists.refresh_discogs_data()
    |> ErrorHandler.to_oban_result()
  end
end
