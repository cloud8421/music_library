defmodule MusicLibrary.Worker.FetchArtistInfo do
  use Oban.Worker, queue: :default, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_id}}) do
    with {:ok, _artist_info} <- MusicLibrary.Artists.fetch_artist_info(artist_id),
         {:ok, _artist_info} <- MusicLibrary.Artists.fetch_wikipedia_data(artist_id),
         {:ok, _artist_info} <- MusicLibrary.Artists.fetch_image(artist_id) do
      regenerate_record_embeddings(artist_id)
    end
  end

  defp regenerate_record_embeddings(artist_id) do
    artist_id
    |> MusicLibrary.Records.get_artist_records()
    |> Enum.each(fn record ->
      MusicLibrary.Records.generate_embedding_async(record)
    end)
  end
end
