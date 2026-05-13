defmodule MusicLibrary.Records.Enrichment do
  @moduledoc """
  Record enrichment: genre population via OpenAI, cover management,
  MusicBrainz data refresh, color extraction, and embedding dispatch.
  """

  require Logger

  alias MusicLibrary.{Assets, Repo, Worker}
  alias MusicLibrary.Records
  alias MusicLibrary.Records.Record

  @color_extractor Application.compile_env(
                     :music_library,
                     :color_extractor,
                     MusicLibrary.Colors.KMeansExtractor
                   )

  @spec populate_genres(Record.t()) :: {:ok, Record.t()} | {:error, Ecto.Changeset.t() | term()}
  def populate_genres(record) do
    artists = Enum.map_join(record.artists, ",", fn a -> a.name end)

    completion = %OpenAI.Completion{
      content: """
      Provide a list of music genres applicable to the album "#{record.title}" by #{artists}.

      Limit the list to 5 genres, ordered by decreasing specificity, all lowercase.

      Return a response in JSON format, without any code block or formatting around it.
      """
    }

    with {:ok, response} <- OpenAI.gpt(completion) do
      record
      |> Record.add_genres(response["genres"])
      |> Repo.update()
    end
  end

  @spec populate_genres_async(Record.t()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def populate_genres_async(record) do
    enqueue_worker(Worker.PopulateGenres, %{"id" => record.id}, record_meta(record))
  end

  @spec refresh_cover(Record.t()) :: {:ok, Record.t()} | {:error, term()}
  def refresh_cover(record) do
    with {:ok, cover_data} <- MusicBrainz.get_cover_art({:url, record.cover_url}),
         {:ok, thumb_data} <- Assets.Image.resize(cover_data),
         {:ok, asset} <- Assets.store_image(%{content: thumb_data, format: "image/jpeg"}) do
      record
      |> Record.set_cover_hash(asset.hash)
      |> Repo.update()
    end
  end

  @spec refresh_cover_async(Record.t()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def refresh_cover_async(record) do
    enqueue_worker(Worker.RefreshCover, %{"id" => record.id}, record_meta(record))
  end

  @doc """
  Extract dominant colors from a record's cover image, swallowing errors.

  Called during record creation. If color extraction fails, the original
  record is returned unchanged and a warning is logged.
  """
  @spec best_effort_extract_colors(Record.t()) :: Record.t()
  def best_effort_extract_colors(record) do
    case maybe_extract_colors(record) do
      {:ok, record} ->
        record

      {:error, reason} ->
        Logger.warning("Color extraction failed for record #{record.id}: #{inspect(reason)}")
        record
    end
  end

  defp maybe_extract_colors(%{dominant_colors: [_ | _]} = record), do: {:ok, record}
  defp maybe_extract_colors(record), do: extract_colors(record)

  @spec extract_colors(Record.t()) :: {:ok, Record.t()} | {:error, term()}
  def extract_colors(record) do
    with {:ok, asset} <- get_asset(record.cover_hash),
         {:ok, colors} <- @color_extractor.extract_dominant_colors(asset.content) do
      Records.update_record(record, %{dominant_colors: colors})
    end
  end

  @spec resize_cover(Record.t()) :: {:ok, Record.t()} | {:error, term()}
  def resize_cover(record) do
    with {:ok, thumb_data} <- Assets.Image.resize(record.cover_data),
         {:ok, asset} <- Assets.store_image(%{content: thumb_data, format: "image/jpeg"}) do
      record
      |> Record.set_cover_hash(asset.hash)
      |> Repo.update()
    end
  end

  @spec refresh_musicbrainz_data(Record.t()) :: {:ok, Record.t()} | {:error, term()}
  def refresh_musicbrainz_data(record) do
    with {:ok, data} <- MusicBrainz.get_release_group(record.musicbrainz_id),
         {:ok, releases} <- MusicBrainz.get_all_releases(record.musicbrainz_id) do
      data_with_releases = Map.put(data, "releases", releases)

      record
      |> Record.add_musicbrainz_data(data_with_releases)
      |> Repo.update()
    end
  end

  @spec refresh_musicbrainz_data_async(Record.t()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def refresh_musicbrainz_data_async(record) do
    enqueue_worker(Worker.RecordRefreshMusicBrainzData, %{"id" => record.id}, record_meta(record))
  end

  defp enqueue_worker(worker, params, meta) do
    params |> worker.new(meta: meta) |> Oban.insert()
  end

  defp record_meta(record) do
    %{title: record.title, artists: Enum.map(record.artists, & &1.name)}
  end

  defp get_asset(cover_hash) do
    if asset = Assets.get(cover_hash) do
      {:ok, asset}
    else
      {:error, :asset_not_found}
    end
  end
end
