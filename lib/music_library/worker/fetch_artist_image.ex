defmodule MusicLibrary.Worker.FetchArtistImage do
  @moduledoc false

  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_id}}) do
    case MusicLibrary.Artists.refresh_image(artist_id) do
      {:ok, _artist_info} -> :ok
      {:error, :image_not_found} -> {:cancel, :image_not_found}
      {:error, :no_discogs_data} -> {:cancel, :no_discogs_data}
      other -> ErrorHandler.to_oban_result(other)
    end
  end
end
