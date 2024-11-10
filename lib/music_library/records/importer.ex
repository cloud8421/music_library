defmodule MusicLibrary.Records.Importer do
  require Logger
  import Ecto.Query, warn: false

  alias MusicLibrary.Records.Record, as: Rec
  alias MusicLibrary.Repo

  def import_all_artists do
    Rec
    |> Repo.all()
    |> Enum.each(fn r ->
      import_artists(r)
      Process.sleep(1000)
    end)
  end

  def import_missing_artists do
    q = from(r in Rec, where: is_nil(r.artists))

    q
    |> Repo.all()
    |> Enum.each(fn r ->
      import_artists(r)
      Process.sleep(1000)
    end)
  end

  def import_artists(record) do
    with {:ok, data} <- musicbrainz().get_release_group(record.musicbrainz_id) do
      artists_attrs =
        data
        |> get_in(["artist-credit", Access.all(), "artist"])
        |> Enum.map(fn artist ->
          %{
            name: artist["name"],
            musicbrainz_id: artist["id"],
            sort_name: artist["sort-name"],
            disambiguation: artist["disambiguation"]
          }
        end)

      record
      |> Rec.add_artists(artists_attrs)
      |> Repo.update!()
    end
  end

  @doc """
  Pull the cover from the stored url and keep a local, resized copy in
  the database for fast access/use.
  """
  def import_cover(record) do
    with {:ok, cover_data} <- blob_get(record.cover_url) do
      {:ok, thumb} = Vix.Vips.Operation.thumbnail_buffer(cover_data, 400)
      {:ok, thumb_data} = Vix.Vips.Image.write_to_buffer(thumb, ".jpg")

      record
      |> Rec.add_cover_data(thumb_data)
      |> Repo.update!()
    end
  end

  @doc """
  Given an already stored cover, resize it to a 400px wide thumbnail.
  """
  def resize_cover(record) do
    {:ok, thumb} = Vix.Vips.Operation.thumbnail_buffer(record.cover_data, 400)
    {:ok, thumb_data} = Vix.Vips.Image.write_to_buffer(thumb, ".jpg")

    record
    |> Rec.add_cover_data(thumb_data)
    |> Repo.update!()
  end

  def import_all_covers do
    Rec
    |> Repo.all()
    |> Enum.each(fn r ->
      if r.cover_data == nil do
        import_cover(r)
        IO.puts("Imported cover for #{r.title}")
      end
    end)
  end

  def resize_all_covers do
    Rec
    |> Repo.all()
    |> Enum.each(fn r ->
      if r.cover_data != nil do
        resize_cover(r)
        IO.puts("Resized cover for #{r.title}")
      end
    end)
  end

  def generate_all_cover_hashes do
    Rec
    |> Repo.all()
    |> Enum.each(fn r ->
      if r.cover_data != nil do
        generate_cover_hash(r)
        IO.puts("Generated cover hash for #{r.title}")
      end
    end)
  end

  def import_missing_musicbrainz_data do
    q = from(r in Rec, where: is_nil(r.musicbrainz_data))

    q
    |> Repo.all()
    |> Enum.each(fn r ->
      import_musicbrainz_data(r)
      Process.sleep(1000)
    end)
  end

  def refresh_musicbrainz_data do
    Rec
    |> Repo.all()
    |> Enum.each(fn r ->
      import_musicbrainz_data(r)
      Process.sleep(1000)
    end)
  end

  def import_musicbrainz_data(record) do
    with {:ok, data} <- musicbrainz().get_release_group(record.musicbrainz_id) do
      record
      |> Rec.add_musicbrainz_data(data)
      |> Repo.update!()
    end
  end

  def generate_cover_hash(record) do
    record
    |> Rec.generate_cover_hash()
    |> Repo.update!()
  end

  defp blob_get(url) do
    req =
      Finch.build(:get, url, [
        {"User-Agent", "MusicLibrary/0.1.0 ( cloud8421@gmail.com )"}
      ])

    Logger.debug("Fetching data from #{url}")

    case Finch.request(req, MusicBrainz.Finch) do
      {:ok, response} when response.status == 200 ->
        {:ok, response.body}

      {:ok, response} when response.status in 301..308 ->
        location = :proplists.get_value("location", response.headers)
        Logger.debug("Following redirect to #{location}")
        blob_get(location)

      other ->
        msg = "Failed to fetch data from #{url}, reason: #{inspect(other)}"
        Logger.error(msg)
        {:error, msg}
    end
  end

  defp musicbrainz do
    Application.get_env(:music_library, :musicbrainz, MusicBrainz.APIImpl)
  end
end
