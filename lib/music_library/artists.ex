defmodule MusicLibrary.Artists do
  @moduledoc """
  Artist metadata management from MusicBrainz, Discogs, Wikipedia, and Last.fm.
  """

  import Ecto.Query, warn: false

  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Assets
  alias MusicLibrary.Records.ArtistRecord
  alias MusicLibrary.{Repo, Worker}

  @spec get_artist!(String.t()) :: map()
  def get_artist!(musicbrainz_id) do
    q =
      from ar in ArtistRecord,
        where: ar.musicbrainz_id == ^musicbrainz_id,
        limit: 1,
        select: ar.artist

    Repo.one!(q)
  end

  @spec get_similar_artists(map(), MapSet.t(String.t())) :: {:ok, [map()]} | {:error, term()}
  def get_similar_artists(artist, collected_artist_ids) do
    with {:ok, artists} <- LastFm.get_similar_artists(artist.musicbrainz_id, artist.name) do
      {:ok, Enum.filter(artists, fn a -> a.musicbrainz_id in collected_artist_ids end)}
    end
  end

  @spec name_id_pairs([String.t()]) :: [{String.t(), String.t()}]
  def name_id_pairs(names) do
    q =
      from ar in ArtistRecord,
        distinct: true,
        where: fragment("artist ->> '$.name'") in ^names,
        select: {fragment("artist ->> '$.name'"), ar.musicbrainz_id}

    Repo.all(q)
  end

  @spec get_all_artist_ids() :: MapSet.t(String.t())
  def get_all_artist_ids do
    q = from ar in ArtistRecord, distinct: true, select: ar.musicbrainz_id

    q |> Repo.all() |> MapSet.new()
  end

  @spec get_all_artist_pairs() :: [map()]
  def get_all_artist_pairs do
    q =
      from ar in ArtistRecord,
        distinct: true,
        select: %{artist_id: ar.musicbrainz_id, record_id: ar.record_id}

    q |> Repo.all()
  end

  @spec get_image_hashes([map()]) :: %{String.t() => String.t() | nil}
  def get_image_hashes(lastfm_artists) do
    musicbrainz_ids = Enum.map(lastfm_artists, & &1.musicbrainz_id)

    q =
      from ai in ArtistInfo,
        where: ai.id in ^musicbrainz_ids,
        select: {ai.id, ai.image_data_hash}

    q
    |> Repo.all()
    |> Enum.into(%{})
  end

  @spec search_by_name(String.t(), non_neg_integer()) :: [map()]
  def search_by_name(query, limit) do
    case String.trim(query) do
      "" ->
        []

      trimmed_query ->
        normalized_query = String.downcase(trimmed_query)

        from(ar in ArtistRecord,
          join: ai in ArtistInfo,
          on: ar.musicbrainz_id == ai.id,
          where:
            fragment("lower(unaccent(artist ->> '$.name')) LIKE ?", ^"%#{normalized_query}%"),
          group_by: ar.musicbrainz_id,
          select: %{artist: ar.artist, image_data_hash: ai.image_data_hash},
          limit: ^limit,
          order_by: fragment("artist ->> '$.name'")
        )
        |> Repo.all()
    end
  end

  @spec search_by_name_count(String.t()) :: non_neg_integer()
  def search_by_name_count(query) do
    case String.trim(query) do
      "" ->
        0

      trimmed_query ->
        normalized_query = String.downcase(trimmed_query)

        from(ar in ArtistRecord,
          where: fragment("lower(artist ->> '$.name') LIKE ?", ^"%#{normalized_query}%"),
          select: ar.musicbrainz_id,
          distinct: true
        )
        |> Repo.aggregate(:count, :musicbrainz_id)
    end
  end

  @spec exists?(String.t()) :: boolean()
  def exists?(artist_id) do
    q =
      from ar in ArtistRecord,
        where: ar.musicbrainz_id == ^artist_id

    Repo.exists?(q)
  end

  @spec delete_artist_info(String.t()) :: {non_neg_integer(), nil | [term()]}
  def delete_artist_info(artist_id) do
    Repo.delete_all(from ai in ArtistInfo, where: ai.id == ^artist_id)
  end

  @spec refresh_artist_info(String.t()) :: {:ok, ArtistInfo.t()} | {:error, term()}
  def refresh_artist_info(artist_id) do
    with {:ok, musicbrainz_artist} <- MusicBrainz.get_artist(artist_id) do
      if discogs_id = MusicBrainz.Artist.get_discogs_id(musicbrainz_artist) do
        with {:ok, discogs_artist} <- Discogs.get_artist(discogs_id) do
          create_artist_info(%{
            id: musicbrainz_artist.id,
            musicbrainz_data: musicbrainz_artist.musicbrainz_data,
            discogs_data: discogs_artist
          })
        end
      else
        create_artist_info(%{
          id: musicbrainz_artist.id,
          musicbrainz_data: musicbrainz_artist.musicbrainz_data
        })
      end
    end
  end

  @spec refresh_musicbrainz_data(String.t()) :: {:ok, ArtistInfo.t()} | {:error, term()}
  def refresh_musicbrainz_data(artist_id) do
    with {:ok, musicbrainz_artist} <- MusicBrainz.get_artist(artist_id) do
      get_artist_info!(artist_id)
      |> ArtistInfo.changeset(%{musicbrainz_data: musicbrainz_artist.musicbrainz_data})
      |> Repo.update()
    end
  end

  @spec refresh_musicbrainz_data_async(ArtistInfo.t()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def refresh_musicbrainz_data_async(artist_info) do
    enqueue_worker(Worker.ArtistRefreshMusicBrainzData, %{"id" => artist_info.id})
  end

  @spec refresh_discogs_data(String.t()) :: {:ok, ArtistInfo.t()} | {:error, term()}
  def refresh_discogs_data(artist_id) do
    artist_info = get_artist_info!(artist_id)

    if discogs_id = ArtistInfo.discogs_id(artist_info) do
      case Discogs.get_artist(discogs_id) do
        {:ok, discogs_artist} ->
          artist_info
          |> ArtistInfo.changeset(%{discogs_data: discogs_artist})
          |> Repo.update()

        error ->
          error
      end
    else
      {:ok, artist_info}
    end
  end

  @spec refresh_discogs_data_async(ArtistInfo.t()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def refresh_discogs_data_async(artist_info) do
    enqueue_worker(Worker.ArtistRefreshDiscogsData, %{"id" => artist_info.id})
  end

  @spec refresh_wikipedia_data(String.t()) :: {:ok, ArtistInfo.t()} | {:error, term()}
  def refresh_wikipedia_data(artist_id) do
    artist_info = get_artist_info!(artist_id)

    if wikidata_id = ArtistInfo.wikidata_id(artist_info) do
      case Wikipedia.get_artist_summary(wikidata_id) do
        {:ok, summary} ->
          artist_info
          |> ArtistInfo.changeset(%{wikipedia_data: summary})
          |> Repo.update()

        error ->
          error
      end
    else
      {:ok, artist_info}
    end
  end

  @spec refresh_wikipedia_data_async(ArtistInfo.t()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def refresh_wikipedia_data_async(artist_info) do
    enqueue_worker(Worker.ArtistRefreshWikipediaData, %{"id" => artist_info.id})
  end

  @spec create_artist_info(map()) :: {:ok, ArtistInfo.t()} | {:error, Ecto.Changeset.t()}
  def create_artist_info(attrs) do
    %ArtistInfo{}
    |> ArtistInfo.changeset(attrs)
    |> Repo.insert(on_conflict: {:replace, [:musicbrainz_data, :discogs_data]})
  end

  @spec get_artist_info!(String.t()) :: ArtistInfo.t()
  def get_artist_info!(artist_id) do
    Repo.get!(ArtistInfo, artist_id)
  end

  @spec get_artist_infos([String.t()]) :: [ArtistInfo.t()]
  def get_artist_infos(artist_ids) do
    q =
      from ai in ArtistInfo, where: ai.id in ^artist_ids

    Repo.all(q)
  end

  @spec refresh_image(String.t()) :: {:ok, ArtistInfo.t()} | {:error, term()}
  def refresh_image(artist_id) do
    artist_info = get_artist_info!(artist_id)

    with {:ok, image} <- ArtistInfo.extract_image(artist_info),
         {:ok, image_data} <- Discogs.get_artist_image(image.url),
         {:ok, asset} <- Assets.store_image(%{content: image_data, format: "image/jpeg"}) do
      artist_info
      |> ArtistInfo.changeset(%{
        image_data_hash: asset.hash
      })
      |> Repo.update()
    end
  end

  @spec refresh_lastfm_data(String.t()) :: {:ok, ArtistInfo.t()} | {:error, term()}
  def refresh_lastfm_data(artist_id) do
    artist_info = get_artist_info!(artist_id)
    name = get_in(artist_info.musicbrainz_data, ["name"]) || ""

    with {:ok, tags} <- LastFm.get_artist_tags(artist_id, name) do
      tag_names = Enum.map(tags, fn {tag_name, _count} -> tag_name end)

      artist_info
      |> ArtistInfo.changeset(%{lastfm_data: %{"tags" => tag_names}})
      |> Repo.update()
    end
  end

  @spec refresh_lastfm_data_async(ArtistInfo.t()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def refresh_lastfm_data_async(artist_info) do
    enqueue_worker(Worker.FetchArtistLastFmData, %{"id" => artist_info.id})
  end

  @spec refresh_artist_info_async(String.t()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def refresh_artist_info_async(artist_id) do
    enqueue_worker(Worker.FetchArtistInfo, %{"id" => artist_id})
  end

  @spec refresh_image_async(String.t()) :: {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def refresh_image_async(artist_id) do
    enqueue_worker(Worker.FetchArtistImage, %{"id" => artist_id})
  end

  @spec prune_artist_info_async(String.t()) ::
          {:ok, Oban.Job.t()} | {:error, Ecto.Changeset.t()}
  def prune_artist_info_async(artist_id) do
    enqueue_worker(Worker.PruneArtistInfo, %{"id" => artist_id})
  end

  @spec change_artist_info(ArtistInfo.t(), map()) :: Ecto.Changeset.t()
  def change_artist_info(artist_info, attrs \\ %{}) do
    ArtistInfo.changeset(artist_info, attrs)
  end

  @spec update_artist_info(ArtistInfo.t(), map()) ::
          {:ok, ArtistInfo.t()} | {:error, Ecto.Changeset.t()}
  def update_artist_info(artist_info, attrs) do
    artist_info
    |> ArtistInfo.changeset(attrs)
    |> Repo.update()
  end

  defp enqueue_worker(worker, params) do
    params |> worker.new(meta: %{}) |> Oban.insert()
  end
end
