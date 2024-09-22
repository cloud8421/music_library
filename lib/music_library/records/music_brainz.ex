defmodule MusicLibrary.Records.MusicBrainz do
  require Logger

  def get_release_group(id) do
    url =
      "https://musicbrainz.org/ws/2/release-group/#{id}?fmt=json&inc=artist-credits"

    json_get(url)
  end

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
