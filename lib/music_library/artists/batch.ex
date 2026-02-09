defmodule MusicLibrary.Artists.Batch do
  import Ecto.Query

  alias MusicLibrary.Artists
  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Repo

  require Logger

  def refresh_musicbrainz_data do
    run_on_all_artist_infos(fn artist_info ->
      Artists.refresh_musicbrainz_data_async(artist_info)
    end)
  end

  def refresh_discogs_data do
    run_on_all_artist_infos(fn artist_info ->
      Artists.refresh_discogs_data_async(artist_info)
    end)
  end

  def refresh_wikipedia_data do
    run_on_all_artist_infos(fn artist_info ->
      Artists.refresh_wikipedia_data_async(artist_info)
    end)
  end

  defp run_on_all_artist_infos(fun) do
    q = from(r in ArtistInfo)
    stream = Repo.stream(q, max_rows: 50)

    Repo.transaction(
      fn ->
        Enum.reduce(stream, [], fn artist_info, acc ->
          case fun.(artist_info) do
            {:error, reason} ->
              Logger.error(
                "Failed to run function on artist_info #{artist_info.id} with #{inspect(reason)}"
              )

              [artist_info.id | acc]

            :ok ->
              acc

            {:ok, _artist_info} ->
              acc
          end
        end)
      end,
      timeout: :infinity
    )
  end
end
