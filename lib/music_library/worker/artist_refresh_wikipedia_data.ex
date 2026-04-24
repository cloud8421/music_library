defmodule MusicLibrary.Worker.ArtistRefreshWikipediaData do
  @moduledoc false

  use Oban.Worker, queue: :wikipedia, max_attempts: 3

  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_info_id}}) do
    case MusicLibrary.Artists.refresh_wikipedia_data(artist_info_id) do
      {:error, :no_english_wikipedia} -> {:cancel, :no_english_wikipedia}
      other -> ErrorHandler.to_oban_result(other)
    end
  end
end
