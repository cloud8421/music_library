defmodule MusicLibrary.Records.MusicBrainz do
  @moduledoc """
  The original data from Obsidian maps records to MusicBrainz release groups, so we can leverage the MusicBrainz API to:

  - Import new records
  - Extend the metadata associated with existing records
  """

  require Logger

  @doc """
  Uses the [lookup](https://musicbrainz.org/doc/MusicBrainz_API#Lookups) endpoint with the release group id and include the
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
  def get_release_group(id) do
    url =
      "https://musicbrainz.org/ws/2/release-group/#{id}?fmt=json&inc=artist-credits"

    json_get(url)
  end

  @doc """
  Uses the [search](https://musicbrainz.org/doc/MusicBrainz_API/Search#Release_Group) endpoint with a search query string.

  Note that the returned release groups are different from a lookup result
  because they don't include **genres** and **cover image**.

  Example request: https://musicbrainz.org/ws/2/release-group?query=marbles&limit=20&offset=0&fmt=json

  Example response:

      {
        "created": "2024-09-23T08:21:24.310Z",
        "count": 2,
        "offset": 0,
        "release-groups": [
          {
            "id": "0b6813e2-8524-4c09-9a57-8dcb9e985f8d",
            "type-id": "6d0c5bf6-7a33-3420-a519-44fc63eedebf",
            "score": 100,
            "primary-type-id": "6d0c5bf6-7a33-3420-a519-44fc63eedebf",
            "count": 1,
            "title": "Eupnea",
            "first-release-date": "2021-05-28",
            "primary-type": "EP",
            "artist-credit": [
              {
                "name": "Ray of Dreams",
                "artist": {
                  "id": "e66e261a-0b52-4801-bbe4-b81c0f157bfe",
                  "name": "Ray of Dreams",
                  "sort-name": "Ray of Dreams"
                }
              }
            ],
            "releases": [
              {
                "id": "b1507d2b-e96a-4838-96d5-c11698bec764",
                "status-id": "4e304316-386d-3409-af2e-78857eec5cfe",
                "title": "Eupnea",
                "status": "Official"
              }
            ]
          },
          {
            "id": "0914b820-6303-4fd6-9bf8-c4662669fe43",
            "type-id": "f529b476-6e62-324f-b0aa-1f3e33d313fc",
            "score": 100,
            "primary-type-id": "f529b476-6e62-324f-b0aa-1f3e33d313fc",
            "count": 3,
            "title": "Eupnea",
            "first-release-date": "2020-04-03",
            "primary-type": "Album",
            "artist-credit": [
              {
                "name": "Pure Reason Revolution",
                "artist": {
                  "id": "f443a331-2623-4d50-8797-bfb204850253",
                  "name": "Pure Reason Revolution",
                  "sort-name": "Pure Reason Revolution"
                }
              }
            ],
            "releases": [
              {
                "id": "3cd333ef-0300-4536-afd7-a23848f01c1e",
                "status-id": "4e304316-386d-3409-af2e-78857eec5cfe",
                "title": "Eupnea",
                "status": "Official"
              },
              {
                "id": "b5da9e78-f174-4d56-b76a-1fa47718e9a4",
                "status-id": "4e304316-386d-3409-af2e-78857eec5cfe",
                "title": "Eupnea",
                "status": "Official"
              },
              {
                "id": "4a374adf-42af-442b-aec0-c9b0da10f32e",
                "status-id": "4e304316-386d-3409-af2e-78857eec5cfe",
                "title": "Eupnea",
                "status": "Official"
              }
            ],
            "tags": [
              {
                "count": 1,
                "name": "rock"
              },
              {
                "count": 1,
                "name": "electronic"
              },
              {
                "count": 1,
                "name": "progressive rock"
              }
            ]
          }
        ]
      }
  """
  def search_release_group(query, opts \\ []) do
    limit = Keyword.get(opts, :limit, 20)
    offset = Keyword.get(opts, :offset, 0)

    qs = [
      query: query,
      limit: limit,
      offset: offset,
      fmt: "json"
    ]

    url =
      "https://musicbrainz.org/ws/2/release-group?#{URI.encode_query(qs)}"

    json_get(url)
  end

  defp json_get(url) do
    req =
      Finch.build(:get, url, [
        {"User-Agent", "MusicLibrary/0.1.0 ( cloud8421@gmail.com )"}
      ])

    Logger.debug("Fetching data from #{url}")

    case Finch.request(req, MusicLibrary.Finch) do
      {:ok, response} when response.status == 200 ->
        {:ok, Jason.decode!(response.body)}

      other ->
        msg = "Failed to fetch data from #{url}, reason: #{inspect(other)}"
        Logger.error(msg)
        {:error, msg}
    end
  end
end
