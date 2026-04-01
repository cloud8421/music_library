defmodule MusicLibrary.Worker.FetchArtistInfo do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_id}}) do
    with {:ok, _artist_info} <- MusicLibrary.Artists.refresh_artist_info(artist_id),
         {:ok, _artist_info} <- MusicLibrary.Artists.refresh_wikipedia_data(artist_id),
         {:ok, _artist_info} <- MusicLibrary.Artists.refresh_image(artist_id) do
      # refresh_lastfm_data returns {:ok, _} even on API errors, so it won't block embeddings
      MusicLibrary.Artists.refresh_lastfm_data(artist_id)
      MusicLibrary.Records.regenerate_artist_embeddings(artist_id)
    else
      {:error, :no_english_wikipedia} -> {:cancel, :no_english_wikipedia}
      error -> error
    end
  end
end
