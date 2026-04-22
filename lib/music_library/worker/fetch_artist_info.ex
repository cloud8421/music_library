defmodule MusicLibrary.Worker.FetchArtistInfo do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias MusicLibrary.Artists
  alias MusicLibrary.Records.Similarity

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_id}}) do
    with {:ok, _artist_info} <- Artists.refresh_artist_info(artist_id),
         {:ok, _artist_info} <- Artists.refresh_wikipedia_data(artist_id),
         {:ok, _artist_info} <- Artists.refresh_image(artist_id),
         {:ok, _artist_info} <- Artists.refresh_lastfm_data(artist_id) do
      Similarity.regenerate_artist_embeddings(artist_id)
    else
      {:error, :no_english_wikipedia} -> {:cancel, :no_english_wikipedia}
      error -> error
    end
  end
end
