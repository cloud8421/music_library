defmodule MusicLibrary.Worker.FetchArtistImage do
  use Oban.Worker, queue: :heavy_writes, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_id}}) do
    case MusicLibrary.Artists.refresh_image(artist_id) do
      {:ok, _artist_info} ->
        :ok

      {:error, :image_not_found} ->
        {:cancel, :image_not_found}

      {:error, :no_discogs_data} ->
        {:cancel, :no_discogs_data}

      error ->
        error
    end
  end
end
