defmodule MusicLibrary.Worker.FetchArtistInfo do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_id}}) do
    with {:ok, _artist_info} <- MusicLibrary.Artists.fetch_artist_info(artist_id),
         {:ok, _artist_info} <- MusicLibrary.Artists.fetch_wikipedia_data(artist_id),
         {:ok, _artist_info} <- MusicLibrary.Artists.fetch_image(artist_id) do
      # fetch_lastfm_data returns {:ok, _} even on API errors, so it won't block embeddings
      MusicLibrary.Artists.fetch_lastfm_data(artist_id)
      MusicLibrary.Records.regenerate_artist_embeddings(artist_id)
    end
  end
end
