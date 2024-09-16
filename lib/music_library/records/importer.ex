defmodule MusicLibrary.Records.Importer do
  require Logger
  import Ecto.Query, warn: false

  alias MusicLibrary.Records.Record, as: Rec

  @moduledoc """
  The original data from Obsidian maps records to release groups, so to find artists for a record we can
  use the [lookup](https://musicbrainz.org/doc/MusicBrainz_API#Lookups) endpoint with the release group id and include the
  artist credits.

  Example request: https://musicbrainz.org/ws/2/release-group/ae504fd6-8498-463e-8d96-14f9e11d1863?fmt=json&inc=artist-credits

  Example response:

      {
        "primary-type-id": "f529b476-6e62-324f-b0aa-1f3e33d313fc",
        "id": "ae504fd6-8498-463e-8d96-14f9e11d1863",
        "primary-type": "Album",
        "secondary-types": [],
        "disambiguation": "",
        "title": "Dwellers of the Deep",
        "secondary-type-ids": [],
        "first-release-date": "2020-10-23",
        "artist-credit": [
          {
            "artist": {
              "type-id": "e431f5f6-b5d2-343d-8b36-72607fffb74b",
              "sort-name": "Wobbler",
              "id": "923b9160-251f-4ebe-8af2-ae670c425e55",
              "type": "Group",
              "name": "Wobbler",
              "disambiguation": "Symphonic Prog, Norway"
            },
            "name": "Wobbler",
            "joinphrase": ""
          }
        ]
      }
  """
  def import_artists(record) do
    url =
      "https://musicbrainz.org/ws/2/release-group/#{record.musicbrainz_id}?fmt=json&inc=artist-credits"

    with {:ok, data} <- json_get(url) do
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
      |> MusicLibrary.Repo.update!()
    end
  end

  def import_cover_image(record) do
    with {:ok, image_data} <- blob_get(record.image_url) do
      record
      |> Rec.add_image_data(image_data)
      |> MusicLibrary.Repo.update!()
    end
  end

  def import_all do
    Rec
    |> MusicLibrary.Repo.all()
    |> Enum.each(fn r ->
      import_artists(r)
      Process.sleep(1000)
    end)
  end

  def import_missing do
    q = from(r in Rec, where: is_nil(r.artists))

    q
    |> MusicLibrary.Repo.all()
    |> Enum.each(fn r ->
      import_artists(r)
      Process.sleep(1000)
    end)
  end

  defp json_get(url) do
    req =
      Finch.build(:get, url, [
        {"User-Agent", "MusicLibrary/0.1.0 ( cloud8421@gmail.com )"}
      ])

    case Finch.request(req, MusicLibrary.Finch) do
      {:ok, response} when response.status == 200 ->
        {:ok, Jason.decode!(response.body)}

      other ->
        msg = "Failed to fetch data from #{url}, reason: #{inspect(other)}"
        Logger.error(msg)
        {:error, msg}
    end
  end

  defp blob_get(url) do
    req =
      Finch.build(:get, url, [
        {"User-Agent", "MusicLibrary/0.1.0 ( cloud8421@gmail.com )"}
      ])

    case Finch.request(req, MusicLibrary.Finch) do
      {:ok, response} when response.status == 200 ->
        {:ok, response.body}

      {:ok, response} when response.status in 301..308 ->
        location = :proplists.get_value("location", response.headers)
        blob_get(location)

      other ->
        msg = "Failed to fetch data from #{url}, reason: #{inspect(other)}"
        Logger.error(msg)
        {:error, msg}
    end
  end
end
