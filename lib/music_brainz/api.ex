defmodule MusicBrainz.API do
  @moduledoc """
  We can leverage the MusicBrainz API to:

  - Import new records
  - Extend the metadata associated with existing records
  """

  alias MusicBrainz.{Artist, ReleaseGroupSearchResult, ReleaseSearchResult}
  alias Req.Request

  require Logger

  @doc """
  Uses the [lookup](https://musicbrainz.org/doc/MusicBrainz_API#Lookups) endpoint with the release group id and include the
  associated artists, genres, releases and release group relations. Note that the API limits each included resource to 25 items.

  > Note that the number of linked entities returned is always limited to 25. If you need the remaining results, you will have to perform a browse request.

  Example request: https://musicbrainz.org/ws/2/release-group/ae504fd6-8498-463e-8d96-14f9e11d1863?fmt=json&inc=artists+releases+genres+release-group-rels


        {
          "primary-type-id": "f529b476-6e62-324f-b0aa-1f3e33d313fc",
          "first-release-date": "2020-10-23",
          "genres": [
            {
              "count": 3,
              "name": "progressive rock",
              "disambiguation": "",
              "id": "ae9b8279-3959-48d8-8a88-741a7f6d4a48"
            },
            {
              "count": 1,
              "name": "rock",
              "disambiguation": "",
              "id": "0e3fc579-2d24-4f20-9dae-736e1ec78798"
            },
            {
              "id": "f729e6f8-30dc-4b81-9ff4-f4e7de82225d",
              "disambiguation": "",
              "count": 1,
              "name": "symphonic rock"
            }
          ],
          "primary-type": "Album",
          "secondary-type-ids": [],
          "releases": [
            {
              "id": "ad9e5d8f-b8ff-4e3e-98be-f26cb8e0682e",
              "quality": "normal",
              "packaging-id": "ec27701a-4a22-37f4-bfac-6616e0f9750a",
              "text-representation": {
                "script": null,
                "language": null
              },
              "date": "2020-10-23",
              "status-id": "4e304316-386d-3409-af2e-78857eec5cfe",
              "country": "NO",
              "genres": [
                {
                  "name": "progressive rock",
                  "count": 1,
                  "id": "ae9b8279-3959-48d8-8a88-741a7f6d4a48",
                  "disambiguation": ""
                }
              ],
              "title": "Dwellers of the Deep",
              "packaging": "Jewel Case",
              "release-events": [
                {
                  "area": {
                    "iso-3166-1-codes": [
                      "NO"
                    ],
                    "type": null,
                    "id": "6743d351-6f37-3049-9724-5041161fff4d",
                    "sort-name": "Norway",
                    "name": "Norway",
                    "disambiguation": "",
                    "type-id": null
                  },
                  "date": "2020-10-23"
                }
              ],
              "barcode": "7090008316497",
              "disambiguation": "",
              "status": "Official"
            },
            {
              "packaging-id": "119eba76-b343-3e02-a292-f0f00644bb9b",
              "quality": "normal",
              "id": "db32822c-27f6-4d1f-8775-df9513c04a9a",
              "date": "2020-10-23",
              "status-id": "4e304316-386d-3409-af2e-78857eec5cfe",
              "text-representation": {
                "script": "Latn",
                "language": "eng"
              },
              "genres": [
                {
                  "disambiguation": "",
                  "id": "93244085-20e5-4f16-9067-1d19143b3810",
                  "name": "classic rock",
                  "count": 2
                },
                {
                  "name": "progressive rock",
                  "count": 2,
                  "disambiguation": "",
                  "id": "ae9b8279-3959-48d8-8a88-741a7f6d4a48"
                },
                {
                  "id": "0e3fc579-2d24-4f20-9dae-736e1ec78798",
                  "disambiguation": "",
                  "count": 2,
  "name": "rock"
                },
                {
                  "count": 2,
                  "name": "symphonic rock",
                  "id": "f729e6f8-30dc-4b81-9ff4-f4e7de82225d",
                  "disambiguation": ""
                }
              ],
              "country": "XW",
              "status": "Official",
              "release-events": [
                {
                  "area": {
                    "disambiguation": "",
                    "type-id": null,
                    "name": "[Worldwide]",
                    "type": null,
                    "sort-name": "[Worldwide]",
                    "id": "525d4e18-3d00-31b9-a58b-a146a916de8f",
                    "iso-3166-1-codes": [
                      "XW"
                    ]
                  },
                  "date": "2020-10-23"
                }
              ],
              "barcode": null,
              "disambiguation": "",
              "title": "Dwellers of the Deep",
              "packaging": "None"
            },
            {
              "id": "5715243e-9c60-49bb-a1cb-4263f065f07b",
              "quality": "normal",
              "packaging-id": "8f931351-d2e2-310f-afc6-37b89ddba246",
              "text-representation": {
                "script": "Latn",
                "language": "eng"
              },
              "status-id": "4e304316-386d-3409-af2e-78857eec5cfe",
              "date": "2020-10-30",
              "country": null,
              "genres": [],
              "barcode": "7090008311942",
              "release-events": [
                {
                  "date": "2020-10-30",
                  "area": null
                }
              ],
              "disambiguation": "",
              "title": "Dwellers of the Deep",
              "packaging": "Digipak",
              "status": "Official"
            }
          ],
          "id": "ae504fd6-8498-463e-8d96-14f9e11d1863",
          "relations": [],
          "secondary-types": [],
          "title": "Dwellers of the Deep",
          "disambiguation": "",
          "artist-credit": [
            {
              "artist": {
                "name": "Wobbler",
                "disambiguation": "symphonic prog, Norway",
                "type-id": "e431f5f6-b5d2-343d-8b36-72607fffb74b",
                "genres": [
                  {
                    "count": 3,
                    "name": "progressive rock",
                    "disambiguation": "",
                    "id": "ae9b8279-3959-48d8-8a88-741a7f6d4a48"
                  },
                  {
                    "name": "symphonic prog",
                    "count": 2,
                    "disambiguation": "",
                    "id": "166be36f-febb-4523-a005-1fb3603bd3f6"
                  }
                ],
                "type": "Group",
                "id": "923b9160-251f-4ebe-8af2-ae670c425e55",
                "sort-name": "Wobbler"
              },
              "name": "Wobbler",
              "joinphrase": ""
            }
          ]
        }
  """

  @spec get_release_group(String.t(), MusicBrainz.Config.t()) :: {:ok, map()} | {:error, term()}
  def get_release_group(id, config) do
    config
    |> new_request()
    |> Req.merge(
      url: "/release-group/#{id}",
      params: [
        fmt: "json",
        inc: "artists+genres+releases+release-group-rels"
      ]
    )
    |> get_request()
  end

  @doc """
  Uses the [lookup](https://musicbrainz.org/doc/MusicBrainz_API#Lookups) endpoint with the release id and include the
  release group.

  Example request: https://musicbrainz.org/ws/2/release/a444b9ca-865d-4f78-a7d9-7e68999e2ca9?fmt=json&inc=release-groups

  Example response:
      {
        "asin": null,
        "barcode": null,
        "country": "XW",
        "cover-art-archive": {
          "artwork": true,
          "back": false,
          "count": 1,
          "darkened": false,
          "front": true
        },
        "date": "2022-05-05",
        "disambiguation": "",
        "id": "a444b9ca-865d-4f78-a7d9-7e68999e2ca9",
        "packaging": null,
        "packaging-id": null,
        "quality": "normal",
        "release-events": [
          {
            "area": {
              "disambiguation": "",
              "id": "525d4e18-3d00-31b9-a58b-a146a916de8f",
              "iso-3166-1-codes": [
                "XW"
              ],
              "name": "[Worldwide]",
              "sort-name": "[Worldwide]",
              "type": null,
              "type-id": null
            },
            "date": "2022-05-05"
          }
        ],
        "release-group": {
          "disambiguation": "",
          "first-release-date": "2022-05-05",
          "id": "6916dd75-e196-4d2f-986f-345579290043",
          "primary-type": "Album",
          "primary-type-id": "f529b476-6e62-324f-b0aa-1f3e33d313fc",
          "secondary-type-ids": [
            "22a628ad-c082-3c4f-b1b6-d41665107b88"
          ],
          "secondary-types": [
            "Soundtrack"
          ],
          "title": "Clark (A Dramatic Score From the Netflix Series)"
        },
        "status": "Official",
        "status-id": "4e304316-386d-3409-af2e-78857eec5cfe",
        "text-representation": {
          "language": null,
          "script": null
        },
        "title": "Clark (Soundtrack From the Netflix Series)"
      }
  """
  @spec get_release(String.t(), MusicBrainz.Config.t()) :: {:ok, map()} | {:error, term()}
  def get_release(id, config) do
    config
    |> new_request()
    |> Req.merge(
      url: "/release/#{id}",
      params: [
        fmt: "json",
        inc: "release-groups+recordings+artists+labels"
      ]
    )
    |> get_request()
  end

  @spec get_releases(String.t(), keyword(), MusicBrainz.Config.t()) ::
          {:ok, map()} | {:error, term()}
  def get_releases(release_group_id, opts, config) do
    Keyword.validate!(opts, [:limit, :offset])

    params =
      Keyword.merge(opts,
        fmt: "json",
        "release-group": release_group_id,
        inc: "media+labels"
      )

    config
    |> new_request()
    |> Req.merge(
      url: "/release",
      params: params
    )
    |> get_request()
  end

  @spec search_release_by_barcode(String.t(), MusicBrainz.Config.t()) ::
          {:ok, [ReleaseSearchResult.t()]} | {:error, term()}
  def search_release_by_barcode(barcode, config) do
    config
    |> new_request()
    |> Req.merge(
      url: "/release",
      params: [
        fmt: "json",
        query: "barcode:#{barcode} AND NOT format:digitalmedia"
      ]
    )
    |> Request.append_response_steps(
      parse_release_search_results: &parse_release_search_results/1
    )
    |> get_request()
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
  @spec search_release_group(String.t(), keyword(), MusicBrainz.Config.t()) ::
          {:ok, %{total_count: non_neg_integer(), release_groups: [ReleaseGroupSearchResult.t()]}}
          | {:error, term()}
  def search_release_group(query, opts, config) do
    Keyword.validate!(opts, [:limit, :offset])

    params =
      Keyword.merge(opts,
        query: query,
        fmt: "json"
      )

    config
    |> new_request()
    |> Req.merge(
      url: "/release-group",
      params: params
    )
    |> Request.append_response_steps(
      parse_release_group_search_results: &parse_release_group_search_results/1
    )
    |> get_request()
  end

  @spec get_artist(String.t(), MusicBrainz.Config.t()) :: {:ok, Artist.t()} | {:error, term()}
  def get_artist(musicbrainz_id, config) do
    config
    |> new_request()
    |> Req.merge(
      url: "/artist/#{musicbrainz_id}",
      params: [
        fmt: "json",
        inc: "url-rels"
      ]
    )
    |> Request.append_response_steps(parse_artist: &parse_artist/1)
    |> get_request()
  end

  @doc """
  Uses the [cover art](https://musicbrainz.org/doc/Cover_Art_Archive/API) endpoint with the release group id to get the cover image.
  """
  @spec get_cover_art({:musicbrainz_id, String.t()} | {:url, String.t()}, MusicBrainz.Config.t()) ::
          {:ok, binary()} | {:error, :cover_not_available}
  def get_cover_art({:musicbrainz_id, musicbrainz_id}, config) do
    url = "https://coverartarchive.org/release-group/#{musicbrainz_id}/front"

    get_cover_art({:url, url}, config)
  end

  def get_cover_art({:url, url}, config) do
    case Req.new(url: url, max_retries: 1, user_agent: config.user_agent)
         |> Request.merge_options(config.req_options)
         |> Request.append_request_steps(log_attempt: &log_attempt/1)
         |> Request.append_response_steps(log_error: &log_error/1)
         |> get_request() do
      {:ok, data} -> {:ok, data}
      {:error, _reason} -> {:error, :cover_not_available}
    end
  end

  defp new_request(config) do
    Req.new(
      base_url: "https://musicbrainz.org/ws/2",
      max_retries: 1,
      user_agent: config.user_agent
    )
    |> Request.merge_options(config.req_options)
    |> Req.RateLimiter.attach(name: :music_brainz, cooldown: config.api_cooldown)
    |> Request.append_request_steps(log_attempt: &log_attempt/1)
  end

  defp get_request(request) do
    case Req.get(request) do
      {:ok, response} when response.status == 200 ->
        {:ok, response.body}

      # all non-success responses can be treated as errors
      {:ok, response} ->
        {:error, response.body}

      error ->
        error
    end
  end

  defp log_attempt(request) do
    url = URI.to_string(request.url)
    Logger.debug("Fetching data from #{url}")
    request
  end

  defp log_error({request, response}) do
    if response.status in 400..499 or response.status in 500..599 do
      Logger.error(fn ->
        url = URI.to_string(request.url)
        "Failed to fetch data from #{url}, reason: #{inspect(response.body)}"
      end)
    end

    {request, response}
  end

  defp parse_release_search_results({request, response}) do
    releases =
      Enum.map(response.body["releases"], &ReleaseSearchResult.from_api_response/1)

    {request, Map.put(response, :body, releases)}
  end

  defp parse_release_group_search_results({request, response}) do
    body = %{
      total_count: response.body["count"],
      release_groups:
        Enum.map(response.body["release-groups"], &ReleaseGroupSearchResult.from_api_response/1)
    }

    {request, Map.put(response, :body, body)}
  end

  defp parse_artist({request, response}) do
    artist = Artist.from_api_response(response.body)

    {request, Map.put(response, :body, artist)}
  end
end
