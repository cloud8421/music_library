defmodule MusicLibrary.Artists do
  import Ecto.Query, warn: false
  alias MusicLibrary.Repo

  alias MusicLibrary.Records.{ArtistInfo, ArtistRecord, Record}
  alias MusicLibrary.{BackgroundRepo, Worker}

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

  def fetch_artist_info(artist_id) do
    case MusicBrainz.get_artist(artist_id) do
      {:ok, musicbrainz_artist} ->
        if discogs_id = MusicBrainz.Artist.get_discogs_id(musicbrainz_artist) do
          case Discogs.get_artist(discogs_id) do
            {:ok, discogs_artist} ->
              %ArtistInfo{}
              |> ArtistInfo.changeset(%{
                id: musicbrainz_artist.id,
                musicbrainz_data: musicbrainz_artist.musicbrainz_data,
                discogs_data: discogs_artist
              })
              |> Repo.insert(on_conflict: {:replace, [:musicbrainz_data, :discogs_data]})

            error ->
              error
          end
        else
          %ArtistInfo{}
          |> ArtistInfo.changeset(%{
            id: musicbrainz_artist.id,
            musicbrainz_data: musicbrainz_artist.musicbrainz_data
          })
          |> Repo.insert(on_conflict: {:replace, [:musicbrainz_data, :discogs_data]})
        end
    end
  end

  def get_artist_info!(artist_id) do
    Repo.get!(ArtistInfo, artist_id)
  end

  def fetch_image(artist_id) do
    artist_info = get_artist_info!(artist_id)

    with {:ok, image} <- ArtistInfo.extract_image(artist_info),
         {:ok, image_data} <- Discogs.get_artist_image(image.url) do
      artist_info
      |> ArtistInfo.changeset(%{
        image_data: image_data,
        image_data_width: image.width
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

  def get_image(artist_id) do
    q =
      from ai in ArtistInfo,
        where: ai.id == ^artist_id,
        select: %{
          image_data: ai.image_data,
          image_data_width: ai.image_data_width,
          image_data_hash: ai.image_data_hash
        }

    Repo.one(q)
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
