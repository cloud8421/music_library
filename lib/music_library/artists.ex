defmodule MusicLibrary.Artists do
  import Ecto.Query, warn: false

  alias MusicLibrary.Artists.ArtistInfo
  alias MusicLibrary.Assets
  alias MusicLibrary.{BackgroundRepo, Repo, Worker}
  alias MusicLibrary.Records.{ArtistRecord, Record}

  def get_artist!(musicbrainz_id) do
    q =
      from ar in ArtistRecord,
        where: ar.musicbrainz_id == ^musicbrainz_id,
        limit: 1,
        select: ar.artist

    Repo.one!(q)
  end

  def get_similar_artists(artist) do
    case LastFm.get_similar_artists(artist.musicbrainz_id, artist.name) do
      {:ok, artists} ->
        collected_artist_ids = get_collected_artist_ids()

        {:ok,
         Enum.filter(artists, fn a ->
           MapSet.member?(collected_artist_ids, a.musicbrainz_id)
         end)}

      error ->
        error
    end
  end

  def name_id_pairs(names) do
    q =
      from ar in ArtistRecord,
        distinct: true,
        where: fragment("artist ->> '$.name'") in ^names,
        select: {fragment("artist ->> '$.name'"), ar.musicbrainz_id}

    Repo.all(q)
  end

  def get_all_artist_ids do
    q = from ar in ArtistRecord, distinct: true, select: ar.musicbrainz_id

    q |> Repo.all() |> MapSet.new()
  end

  def get_all_artist_pairs do
    q =
      from ar in ArtistRecord,
        distinct: true,
        select: %{artist_id: ar.musicbrainz_id, record_id: ar.record_id}

    q |> Repo.all()
  end

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

  def exists?(artist_id) do
    q =
      from ar in ArtistRecord,
        where: ar.musicbrainz_id == ^artist_id

    Repo.exists?(q)
  end

  def delete_artist_info(artist_id) do
    Repo.delete_all(from ai in ArtistInfo, where: ai.id == ^artist_id)
  end

  def fetch_artist_info(artist_id) do
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

  def create_artist_info(attrs) do
    %ArtistInfo{}
    |> ArtistInfo.changeset(attrs)
    |> Repo.insert(on_conflict: {:replace, [:musicbrainz_data, :discogs_data]})
  end

  def get_artist_info!(artist_id) do
    Repo.get!(ArtistInfo, artist_id)
  end

  def fetch_image(artist_id) do
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

  def fetch_artist_info_async(artist_id) do
    meta = %{}
    params = %{"id" => artist_id}

    params
    |> Worker.FetchArtistInfo.new(meta: meta)
    |> BackgroundRepo.insert()
  end

  def fetch_image_async(artist_id) do
    meta = %{}
    params = %{"id" => artist_id}

    params
    |> Worker.FetchArtistImage.new(meta: meta)
    |> BackgroundRepo.insert()
  end

  def prune_artist_info_async(artist_id) do
    meta = %{}
    params = %{"id" => artist_id}

    params
    |> Worker.PruneArtistInfo.new(meta: meta)
    |> BackgroundRepo.insert()
  end

  def change_artist_info(artist_info, attrs \\ %{}) do
    ArtistInfo.changeset(artist_info, attrs)
  end

  def update_artist_info(artist_info, attrs) do
    artist_info
    |> ArtistInfo.changeset(attrs)
    |> Repo.update()
  end

  defp get_collected_artist_ids do
    q =
      from ar in ArtistRecord,
        join: r in Record,
        on: r.id == ar.record_id,
        where: not is_nil(r.purchased_at),
        distinct: true,
        select: ar.musicbrainz_id

    q |> Repo.all() |> MapSet.new()
  end
end
