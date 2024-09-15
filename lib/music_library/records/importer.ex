defmodule MusicLibrary.Records.Importer do
  alias Ecto.Multi

  @doc """
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
      current_time =
        DateTime.utc_now()
        |> DateTime.truncate(:second)

      artist_entries =
        data
        |> get_in(["artist-credit", Access.all(), "artist"])
        |> Enum.map(fn artist ->
          %{
            name: artist["name"],
            musicbrainz_id: artist["id"],
            inserted_at: current_time,
            updated_at: current_time
          }
        end)

      Multi.new()
      |> Multi.insert_all(:artists, MusicLibrary.Records.Artist, artist_entries,
        on_conflict: :nothing,
        returning: true
      )
      |> Multi.insert_all(:artists_records, MusicLibrary.Records.ArtistRecord, fn %{
                                                                                    artists:
                                                                                      {_inserted_count,
                                                                                       artists}
                                                                                  } ->
        Enum.map(artists, fn a ->
          %{
            artist_id: a.id,
            record_id: record.id,
            inserted_at: current_time,
            updated_at: current_time
          }
        end)
      end)
      |> MusicLibrary.Repo.transaction()
    end
  end

  defp json_get(url) do
    case Finch.build(:get, url) |> Finch.request(MusicLibrary.Finch) do
      {:ok, response} when response.status == 200 ->
        {:ok, Jason.decode!(response.body)}

      other ->
        {:error, "Failed to fetch data from #{url}, reason: #{inspect(other)}"}
    end
  end
end
