defmodule MusicLibrary.Worker.ArtistRefreshMusicBrainzData do
  @moduledoc false

  use Oban.Worker, queue: :music_brainz, max_attempts: 3

  alias MusicLibrary.Worker.ErrorHandler

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"id" => artist_info_id}}) do
    artist_info_id
    |> MusicLibrary.Artists.refresh_musicbrainz_data()
    |> ErrorHandler.to_oban_result()
  end
end
